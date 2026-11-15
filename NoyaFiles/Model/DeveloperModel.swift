import AppKit
import NoyaCore
import Observation

/// What Git says about a repository.
struct GitStatus: Sendable, Hashable {
    var branch: String?
    var ahead = 0
    var behind = 0
    /// Lines of `git status --porcelain`, such as ` M src/App.swift`.
    var changes: [String] = []
    var lastCommitSubject: String?
    var lastCommitDate: Date?
    var remote: String?

    var isClean: Bool { changes.isEmpty && ahead == 0 && behind == 0 }
}

/// A folder of code, with what NOYA Files found out about it.
struct DeveloperProject: Identifiable, Hashable, Sendable {
    let url: URL
    let isRepository: Bool
    let language: String?
    var git: GitStatus?
    var bytes: Int64?
    /// Build folders and dependencies that can be recreated, with their sizes.
    var caches: [SpaceCandidate] = []

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var cacheBytes: Int64 { caches.reduce(0) { $0 + $1.bytes } }
}

/// An app that can open a folder, such as Terminal or an editor.
struct ExternalApp: Identifiable, Hashable {
    let bundleIdentifier: String
    let name: String
    let url: URL

    var id: String { bundleIdentifier }
}

/// Lists the projects of a folder and keeps their Git state up to date.
@MainActor
@Observable
final class DeveloperModel {
    static let shared = DeveloperModel()
    private static let rootKey = "developer.root"
    private static let editorKey = "developer.editor"
    private static let terminalKey = "developer.terminal"

    private(set) var root: URL
    private(set) var projects: [DeveloperProject] = []
    private(set) var isLoading = false
    private(set) var hasGit = false
    /// Whether Git and folder sizes have been read since the last change of folder.
    private(set) var hasDetails = false
    var selection: URL?

    let editors: [ExternalApp]
    let terminals: [ExternalApp]

    var editorID: String {
        didSet { UserDefaults.standard.set(editorID, forKey: Self.editorKey) }
    }

    var terminalID: String {
        didSet { UserDefaults.standard.set(terminalID, forKey: Self.terminalKey) }
    }

    let runner = CommandRunner()

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let stored = UserDefaults.standard.string(forKey: Self.rootKey) {
            root = URL(fileURLWithPath: stored, isDirectory: true)
        } else {
            let candidates = ["Developer", "Projects", "Projets", "Code", "dev", "src", "GitHub"]
                .map { home.appendingPathComponent($0, isDirectory: true) }
            root = candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? home
        }
        editors = Self.installedApps([
            ("com.microsoft.VSCode", "Visual Studio Code"),
            ("com.todesktop.230313mzl4w4u92", "Cursor"),
            ("dev.zed.Zed", "Zed"),
            ("com.apple.dt.Xcode", "Xcode"),
            ("com.sublimetext.4", "Sublime Text"),
            ("com.panic.Nova", "Nova"),
            ("com.jetbrains.intellij", "IntelliJ IDEA"),
        ])
        terminals = Self.installedApps([
            ("com.apple.Terminal", "Terminal"),
            ("com.googlecode.iterm2", "iTerm"),
            ("dev.warp.Warp-Stable", "Warp"),
            ("com.mitchellh.ghostty", "Ghostty"),
        ])
        editorID = UserDefaults.standard.string(forKey: Self.editorKey) ?? editors.first?.bundleIdentifier ?? ""
        terminalID = UserDefaults.standard.string(forKey: Self.terminalKey) ?? "com.apple.Terminal"
    }

    var selectedProject: DeveloperProject? {
        projects.first { $0.url == selection }
    }

    var repositories: [DeveloperProject] {
        projects.filter(\.isRepository)
    }

    var editor: ExternalApp? { editors.first { $0.bundleIdentifier == editorID } ?? editors.first }
    var terminal: ExternalApp? { terminals.first { $0.bundleIdentifier == terminalID } ?? terminals.first }

    // MARK: - Loading

    func setRoot(_ url: URL) {
        root = url
        UserDefaults.standard.set(url.path, forKey: Self.rootKey)
        projects = []
        selection = nil
        hasDetails = false
        reload()
    }

    /// Lists the projects quickly, without asking Git or measuring folders, for the sidebar.
    func listIfNeeded() {
        guard projects.isEmpty, !isLoading else { return }
        let root = self.root
        Task { [weak self] in
            let found = await Self.findProjects(in: root)
            guard let self, self.projects.isEmpty else { return }
            self.projects = found
        }
    }

    func reloadIfNeeded() {
        if !hasDetails, !isLoading { reload() }
    }

    func reload() {
        loadTask?.cancel()
        isLoading = true
        let root = self.root
        loadTask = Task { [weak self] in
            let gitPath = await Self.findGit()
            let found = await Self.findProjects(in: root)
            guard let self, !Task.isCancelled else { return }
            self.hasGit = gitPath != nil
            // Keeps what is already known while the details load again.
            let previous = Dictionary(self.projects.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
            self.projects = found.map { project in
                guard let known = previous[project.url] else { return project }
                var merged = project
                merged.git = known.git
                merged.bytes = known.bytes
                merged.caches = known.caches
                return merged
            }
            if self.selection == nil || !found.contains(where: { $0.url == self.selection }) {
                self.selection = found.first(where: \.isRepository)?.url ?? found.first?.url
            }

            for project in found {
                if Task.isCancelled { return }
                let details = await Self.details(for: project, gitPath: gitPath)
                if let index = self.projects.firstIndex(where: { $0.url == project.url }) {
                    self.projects[index] = details
                }
            }
            self.isLoading = false
            self.hasDetails = true
        }
    }

    // MARK: - Actions

    func openInEditor(_ url: URL) {
        open(url, with: editor)
    }

    func openInTerminal(_ url: URL) {
        open(url, with: terminal)
    }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    /// Moves a project's build folders and dependencies to the Trash, or only one of them.
    func trashCaches(of project: DeveloperProject, only cache: SpaceCandidate? = nil) -> Int64 {
        var freed: Int64 = 0
        var trashed: Set<URL> = []
        for candidate in project.caches where cache == nil || candidate.url == cache?.url {
            if (try? FileManager.default.trashItem(at: candidate.url, resultingItemURL: nil)) != nil {
                freed += candidate.bytes
                trashed.insert(candidate.url)
            }
        }
        if let index = projects.firstIndex(where: { $0.url == project.url }) {
            projects[index].caches.removeAll { trashed.contains($0.url) }
            if let bytes = projects[index].bytes {
                projects[index].bytes = max(0, bytes - freed)
            }
        }
        return freed
    }

    private func open(_ url: URL, with app: ExternalApp?) {
        guard let app else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    // MARK: - Work done off the main thread

    nonisolated private static func findProjects(in root: URL) async -> [DeveloperProject] {
        let fileManager = FileManager.default
        let folders = ((try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }

        return folders
            .map { folder in
                DeveloperProject(
                    url: folder,
                    isRepository: fileManager.fileExists(atPath: folder.appendingPathComponent(".git").path),
                    language: language(of: folder)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func language(of folder: URL) -> String? {
        let markers: [(String, String)] = [
            ("Package.swift", "Swift"), ("Cargo.toml", "Rust"), ("go.mod", "Go"),
            ("tsconfig.json", "TypeScript"), ("package.json", "JavaScript"),
            ("pyproject.toml", "Python"), ("requirements.txt", "Python"),
            ("build.gradle.kts", "Kotlin"), ("build.gradle", "Java"), ("pom.xml", "Java"),
            ("Gemfile", "Ruby"), ("composer.json", "PHP"), ("pubspec.yaml", "Dart"),
            ("CMakeLists.txt", "C++"), ("Makefile", "C"),
        ]
        let names = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        if names.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) { return "Swift" }
        if let marker = markers.first(where: { names.contains($0.0) }) {
            return marker.1
        }
        // No project file: the most common kind of source file at the top of the folder.
        let extensions = ["swift": "Swift", "ts": "TypeScript", "js": "JavaScript", "py": "Python", "go": "Go",
                          "rs": "Rust", "kt": "Kotlin", "java": "Java", "rb": "Ruby", "php": "PHP", "sh": "Shell",
                          "c": "C", "cpp": "C++", "m": "Objective-C"]
        let counts = names.reduce(into: [String: Int]()) { counts, name in
            if let language = extensions[(name as NSString).pathExtension.lowercased()] {
                counts[language, default: 0] += 1
            }
        }
        return counts.max { $0.value < $1.value }?.key
    }

    nonisolated private static func details(for project: DeveloperProject, gitPath: String?) async -> DeveloperProject {
        var result = project
        if project.isRepository {
            result.git = gitStatus(of: project.url, gitPath: gitPath)
        }
        // Folders that a build or an install recreates, with the command that does it.
        let caches: [(String, String)] = [
            ("node_modules", "npm install"), (".build", "swift build"), ("DerivedData", "xcodebuild"),
            ("build", "make"), ("target", "cargo build"), (".gradle", "./gradlew build"),
            (".venv", "pip install -r requirements.txt"), ("venv", "pip install -r requirements.txt"),
            ("dist", "npm run build"), (".next", "next build"),
        ]
        for (name, command) in caches {
            let url = project.url.appendingPathComponent(name, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let bytes = FolderSizer.measure(url).bytes
            if bytes > 1_000_000 {
                result.caches.append(SpaceCandidate(url: url, title: name, detail: command, bytes: bytes))
            }
        }
        result.bytes = FolderSizer.measure(project.url).bytes
        return result
    }

    nonisolated private static func gitStatus(of folder: URL, gitPath: String?) -> GitStatus {
        var status = GitStatus()
        // The branch can be read without Git installed.
        if let head = try? String(contentsOf: folder.appendingPathComponent(".git/HEAD"), encoding: .utf8) {
            let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
            status.branch = trimmed.hasPrefix("ref: refs/heads/") ? String(trimmed.dropFirst("ref: refs/heads/".count)) : String(trimmed.prefix(7))
        }
        guard let gitPath else { return status }

        if let output = run(gitPath, ["status", "--porcelain=v1", "--branch"], in: folder) {
            for line in output.split(separator: "\n").map(String.init) {
                if line.hasPrefix("## ") {
                    if let range = line.range(of: "ahead ") {
                        status.ahead = Int(line[range.upperBound...].prefix { $0.isNumber }) ?? 0
                    }
                    if let range = line.range(of: "behind ") {
                        status.behind = Int(line[range.upperBound...].prefix { $0.isNumber }) ?? 0
                    }
                } else if !line.isEmpty {
                    status.changes.append(line)
                }
            }
        }
        if let output = run(gitPath, ["log", "-1", "--format=%s%x1f%ct"], in: folder) {
            let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\u{1f}", omittingEmptySubsequences: false)
            if parts.count == 2 {
                status.lastCommitSubject = String(parts[0])
                status.lastCommitDate = TimeInterval(parts[1]).map(Date.init(timeIntervalSince1970:))
            }
        }
        if let remote = run(gitPath, ["config", "--get", "remote.origin.url"], in: folder)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !remote.isEmpty {
            status.remote = remote
        }
        return status
    }

    /// Finds Git without triggering the “install developer tools” prompt when they are missing.
    nonisolated private static func findGit() async -> String? {
        let candidates = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated private static func run(_ executable: String, _ arguments: [String], in folder: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["LC_ALL"] = "C"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func installedApps(_ candidates: [(String, String)]) -> [ExternalApp] {
        candidates.compactMap { identifier, name in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
                .map { ExternalApp(bundleIdentifier: identifier, name: name, url: $0) }
        }
    }
}

/// Runs shell commands in a project folder and shows their output as it comes.
@MainActor
@Observable
final class CommandRunner {
    private(set) var output = ""
    private(set) var isRunning = false
    @ObservationIgnored private var process: Process?

    private static let maxCharacters = 60_000

    func run(_ command: String, in folder: URL) {
        stop()
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append("$ \(trimmed)\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", trimmed]
        process.currentDirectoryURL = folder
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                // The end of the output.
                handle.readabilityHandler = nil
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.append(text) }
        }
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            Task { @MainActor in
                self?.isRunning = false
                self?.process = nil
                if status != 0 { self?.append(String(localized: "Exited with code \(Int(status))") + "\n") }
            }
        }
        do {
            try process.run()
            self.process = process
            isRunning = true
        } catch {
            append(error.localizedDescription + "\n")
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    func clear() {
        output = ""
    }

    private func append(_ text: String) {
        output += text
        if output.count > Self.maxCharacters {
            output = String(output.suffix(Self.maxCharacters))
        }
    }
}
