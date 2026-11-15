import AppKit
import NoyaCore
import SwiftUI

/// The projects of a folder, with their Git state, sizes and build caches, and a terminal.
struct DeveloperScreen: View {
    @Bindable private var model = DeveloperModel.shared
    @AppStorage("developer.terminalVisible") private var isTerminalVisible = true
    @State private var isInspectorPresented = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.projects.isEmpty, !model.isLoading {
                ContentUnavailableView {
                    Label("No Projects Here", systemImage: "chevron.left.forwardslash.chevron.right")
                } description: {
                    Text("Choose the folder where you keep your code, such as ~/Developer.")
                } actions: {
                    Button("Choose Folder…", action: chooseRoot)
                }
            } else {
                ProjectTable(model: model)
            }
            if isTerminalVisible, let project = model.selectedProject {
                Divider()
                TerminalPanel(runner: model.runner, folder: project.url, branch: project.git?.branch)
                    .frame(height: 210)
            }
        }
        .navigationTitle("Developer Tools")
        .toolbar { toolbar }
        .inspector(isPresented: $isInspectorPresented) {
            Group {
                if let project = model.selectedProject {
                    ProjectInspector(project: project, model: model)
                } else {
                    ContentUnavailableView("No Project Selected", systemImage: "folder")
                }
            }
            .inspectorColumnWidth(min: 250, ideal: 290, max: 380)
        }
        .onAppear { model.reloadIfNeeded() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(Self.abbreviated(model.root))
                .font(.callout.monospaced())
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            if !model.hasGit, model.hasDetails {
                Label("Git not found: install the Command Line Tools to see branches and changes.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                if let url = model.selectedProject?.url { model.openInTerminal(url) }
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }
            .help("Open in Terminal")
            .disabled(model.selectedProject == nil)

            Button {
                if let url = model.selectedProject?.url { model.openInEditor(url) }
            } label: {
                Label("Open in Editor", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .help(model.editor.map { String(localized: "Open in \($0.name)") } ?? String(localized: "Open in Editor"))
            .disabled(model.selectedProject == nil)

            Button {
                if let url = model.selectedProject?.url { model.copyPath(url) }
            } label: {
                Label("Copy Path", systemImage: "doc.on.clipboard")
            }
            .help("Copy Path")
            .disabled(model.selectedProject == nil)
        }
        ToolbarItemGroup {
            Button {
                isTerminalVisible.toggle()
            } label: {
                Label("Terminal", systemImage: "apple.terminal")
            }
            .keyboardShortcut("`", modifiers: .control)
            .help("Show or hide the terminal (⌃`)")

            Button(action: chooseRoot) {
                Label("Projects Folder", systemImage: "folder.badge.gearshape")
            }
            .help("Choose the folder where you keep your projects")

            Button {
                model.reload()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Read the projects again")
            .disabled(model.isLoading)

            Button {
                isInspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Show or hide the details")
        }
    }

    private func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = model.root
        panel.prompt = String(localized: "Choose")
        if panel.runModal() == .OK, let url = panel.url {
            model.setRoot(url)
        }
    }

    static func abbreviated(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

// MARK: - Table

private struct ProjectTable: View {
    @Bindable var model: DeveloperModel

    var body: some View {
        Table(model.projects, selection: $model.selection) {
            TableColumn("Name") { project in
                Label {
                    Text(project.name)
                } icon: {
                    Image(systemName: project.isRepository ? "folder.badge.gearshape" : "folder")
                        .foregroundStyle(project.isRepository ? Color.accentColor : .secondary)
                }
            }
            .width(min: 140, ideal: 180)

            TableColumn("Branch") { project in
                if let branch = project.git?.branch {
                    Text(branch)
                        .font(.callout.monospaced())
                } else {
                    Text(verbatim: "—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 80, ideal: 110)

            TableColumn("Status") { project in
                GitStatusText(project: project, isLoaded: model.hasDetails || project.git != nil)
            }
            .width(min: 90, ideal: 120)

            TableColumn("Language") { project in
                Text(project.language ?? "—")
                    .foregroundStyle(project.language == nil ? HierarchicalShapeStyle.tertiary : .primary)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Last Commit") { project in
                if let date = project.git?.lastCommitDate {
                    Text(date, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: "—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 90, ideal: 110)

            TableColumn("Size") { project in
                if let bytes = project.bytes {
                    Text(bytes.formattedByteCount)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView().controlSize(.mini)
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("Caches") { project in
                if let biggest = project.caches.max(by: { $0.bytes < $1.bytes }) {
                    Text(verbatim: "\(biggest.title) \(biggest.bytes.formattedByteCount)")
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                } else {
                    Text(verbatim: "—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 100, ideal: 150)
        }
        .contextMenu(forSelectionType: URL.self) { urls in
            if let url = urls.first {
                Button("Open in Terminal") { model.openInTerminal(url) }
                Button("Open in Editor") { model.openInEditor(url) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Divider()
                Button("Copy Path") { model.copyPath(url) }
            }
        } primaryAction: { urls in
            if let url = urls.first { model.openInEditor(url) }
        }
    }
}

private struct GitStatusText: View {
    let project: DeveloperProject
    let isLoaded: Bool

    var body: some View {
        if !project.isRepository {
            Text("Not a repository")
                .foregroundStyle(.tertiary)
        } else if let git = project.git {
            if git.isClean {
                Label("Up to date", systemImage: "checkmark")
                    .foregroundStyle(.green)
            } else if !git.changes.isEmpty {
                Label(String(localized: "\(git.changes.count) modified"), systemImage: "circle.fill")
                    .foregroundStyle(.orange)
                    .labelStyle(SmallIconLabelStyle())
            } else {
                Text(verbatim: "↑\(git.ahead) ↓\(git.behind)")
                    .foregroundStyle(.blue)
                    .monospacedDigit()
            }
        } else if isLoaded {
            Text(verbatim: "—").foregroundStyle(.tertiary)
        } else {
            ProgressView().controlSize(.mini)
        }
    }
}

private struct SmallIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 7))
            configuration.title
        }
    }
}

// MARK: - Inspector

private struct ProjectInspector: View {
    let project: DeveloperProject
    let model: DeveloperModel
    @State private var cacheToClean: SpaceCandidate?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title2.weight(.semibold))
                    Text(summary)
                        .foregroundStyle(.secondary)
                }

                if let git = project.git {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                        if let branch = git.branch {
                            GridRow {
                                Text("Branch").foregroundStyle(.secondary)
                                Text(branch).font(.callout.monospaced())
                            }
                        }
                        if let remote = git.remote {
                            GridRow {
                                Text("Remote").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Self.shortRemote(remote))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .textSelection(.enabled)
                                    if git.ahead > 0 || git.behind > 0 {
                                        Text(aheadBehind(git))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if let subject = git.lastCommitSubject {
                            GridRow {
                                Text("Last Commit").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: "« \(subject) »")
                                        .lineLimit(3)
                                    if let date = git.lastCommitDate {
                                        Text(date, format: .relative(presentation: .named))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if !git.changes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            PanelSectionTitle("Changes")
                            ForEach(git.changes.prefix(30), id: \.self) { line in
                                ChangeRow(line: line)
                            }
                            if git.changes.count > 30 {
                                Text(String(localized: "and \(git.changes.count - 30) more"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ForEach(project.caches) { cache in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "\(cache.title) · \(cache.bytes.formattedByteCount)")
                            .font(.headline)
                        let command = Text(cache.detail).font(.callout.monospaced())
                        Text("Rebuilt with \(command). The folder goes to the Trash.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("Clean") { cacheToClean = cache }
                            .controlSize(.small)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(spacing: 8) {
                    Button {
                        model.openInEditor(project.url)
                    } label: {
                        Label(model.editor.map { String(localized: "Open in \($0.name)") } ?? String(localized: "Open in Editor"), systemImage: "chevron.left.forwardslash.chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        model.openInTerminal(project.url)
                    } label: {
                        Label("Open in Terminal", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                    }
                }
                .controlSize(.large)
            }
            .padding(16)
        }
        .confirmationDialog(
            String(localized: "Move \(cleanTitle) to the Trash?"),
            isPresented: Binding(get: { cacheToClean != nil }, set: { if !$0 { cacheToClean = nil } }),
            titleVisibility: .visible,
            presenting: cacheToClean
        ) { cache in
            Button("Move to Trash", role: .destructive) {
                let freed = model.trashCaches(of: project, only: cache)
                NoticeCenter.shared.show(String(localized: "\(freed.formattedByteCount) freed"), symbolName: "sparkles")
            }
        } message: { cache in
            Text("It will be recreated by \(cache.detail).")
        }
    }

    private var cleanTitle: String {
        cacheToClean?.title ?? ""
    }

    private var summary: String {
        var parts: [String] = [project.isRepository ? String(localized: "Git repository") : String(localized: "Folder")]
        if let language = project.language { parts.append(language) }
        if let bytes = project.bytes { parts.append(bytes.formattedByteCount) }
        return parts.joined(separator: " · ")
    }

    private func aheadBehind(_ git: GitStatus) -> String {
        var parts: [String] = []
        if git.ahead > 0 { parts.append(String(localized: "\(git.ahead) commits ahead")) }
        if git.behind > 0 { parts.append(String(localized: "\(git.behind) commits behind")) }
        return parts.joined(separator: " · ")
    }

    /// “github.com/noya360/site-web” from “git@github.com:noya360/site-web.git”.
    static func shortRemote(_ remote: String) -> String {
        var text = remote
        for prefix in ["https://", "http://", "ssh://", "git@"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasSuffix(".git") { text.removeLast(4) }
        return text.replacingOccurrences(of: ":", with: "/")
    }
}

private struct ChangeRow: View {
    let line: String

    var body: some View {
        let code = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
        let path = String(line.dropFirst(3))
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(code.isEmpty ? "M" : code)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(color(for: code))
                .frame(width: 22, alignment: .leading)
            Text(path)
                .font(.callout.monospaced())
                .lineLimit(1)
                .truncationMode(.head)
        }
    }

    private func color(for code: String) -> Color {
        if code.contains("?") { return .secondary }
        if code.contains("D") { return .red }
        if code.contains("A") { return .green }
        return .orange
    }
}

// MARK: - Terminal

/// Runs commands in the selected project and shows what they print.
private struct TerminalPanel: View {
    let runner: CommandRunner
    let folder: URL
    let branch: String?
    @State private var command = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label("Terminal", systemImage: "apple.terminal")
                    .font(.callout.weight(.semibold))
                Text(DeveloperScreen.abbreviated(folder))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("⌃` to show or hide")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button {
                    runner.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(runner.output.isEmpty ? " " : runner.output)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    Color.clear.frame(height: 1).id("end")
                }
                .onChange(of: runner.output) {
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }

            HStack(spacing: 6) {
                Text(verbatim: "\(folder.lastPathComponent)\(branch.map { " (\($0))" } ?? "") $")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                TextField("Command", text: $command)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .focused($isFocused)
                    .onSubmit {
                        runner.run(command, in: folder)
                        command = ""
                    }
                if runner.isRunning {
                    Button("Stop") { runner.stop() }
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
