import AppKit
import NoyaCore
import Observation

/// Something that could be removed to free space, such as a big file or a cache.
struct SpaceCandidate: Identifiable, Hashable, Sendable {
    let url: URL
    let title: String
    let detail: String
    let bytes: Int64

    var id: URL { url }
}

/// One part of the disk, such as Applications or Photos and videos.
struct SpaceSlice: Identifiable, Hashable {
    let id: String
    let title: String
    let bytes: Int64
    let tint: FileCategory
}

/// Looks through the Mac for space that can be freed. Results are kept between visits.
@MainActor
@Observable
final class SpaceAnalyzer {
    static let shared = SpaceAnalyzer()

    private(set) var isScanning = false
    private(set) var lastScan: Date?
    private(set) var disk: DiskUsage?
    private(set) var slices: [SpaceSlice] = []
    private(set) var largeFiles: [SpaceCandidate] = []
    private(set) var developerCaches: [SpaceCandidate] = []
    private(set) var installers: [SpaceCandidate] = []
    private(set) var duplicateGroups: [[FileItem]] = []
    private(set) var trashBytes: Int64?
    private(set) var trashCount = 0
    private(set) var canReadTrash = true
    var selection: Set<URL> = []

    @ObservationIgnored private var scanTask: Task<Void, Never>?

    var reclaimableBytes: Int64 {
        largeFiles.reduce(0) { $0 + $1.bytes }
            + developerCaches.reduce(0) { $0 + $1.bytes }
            + installers.reduce(0) { $0 + $1.bytes }
            + DuplicateFinder.reclaimableBytes(in: duplicateGroups)
            + (trashBytes ?? 0)
    }

    var selectedBytes: Int64 {
        let all = largeFiles + developerCaches + installers
        return all.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.bytes }
    }

    // MARK: - Scanning

    func scanIfNeeded() {
        guard lastScan == nil, !isScanning else { return }
        scan()
    }

    func scan() {
        scanTask?.cancel()
        isScanning = true
        disk = Self.startupDisk()

        scanTask = Task { [weak self] in
            let home = FileManager.default.homeDirectoryForCurrentUser

            let hits = await Spotlight.find("kMDItemFSSize >= 500000000", in: [NSMetadataQueryUserHomeScope], limit: 60)
            self?.largeFiles = hits
                .filter { !$0.url.path.contains("/Library/") }
                .sorted { $0.size > $1.size }
                .prefix(20)
                .map { hit in
                    SpaceCandidate(url: hit.url, title: hit.url.lastPathComponent, detail: Self.usageDetail(for: hit), bytes: hit.size)
                }

            let modules = await Spotlight.find("kMDItemFSName == \"node_modules\" && kMDItemContentType == \"public.folder\"", in: [NSMetadataQueryUserHomeScope], limit: 400)
            let caches = await Self.measureDeveloperCaches(home: home, nodeModules: modules.map(\.url))
            self?.developerCaches = caches
            if self?.selection.isEmpty == true {
                self?.selection = Set(caches.filter { $0.url.lastPathComponent == "DerivedData" || $0.url.path.contains("/Caches/") }.map(\.url))
            }

            let downloads = await Self.readFolder(.downloadsDirectory)
            let apps = InstalledAppMatcher.installedAppNames()
            let installers = downloads.compactMap { item -> SpaceCandidate? in
                guard item.category == .installers, item.kind == .file,
                      let app = InstalledAppMatcher.installedApp(forInstaller: item.name, among: apps) else { return nil }
                return SpaceCandidate(url: item.url, title: item.name, detail: String(localized: "\(app) is already installed"), bytes: item.size)
            }
            self?.installers = installers
            self?.selection.formUnion(installers.map(\.url))

            self?.duplicateGroups = await Self.findDuplicates(home: home)

            let trash = await Self.measureTrash()
            self?.canReadTrash = trash != nil
            self?.trashBytes = trash?.bytes
            self?.trashCount = trash?.itemCount ?? 0

            let slices = await Self.measureSlices(home: home, developerBytes: caches.reduce(0) { $0 + $1.bytes })
            guard let self, !Task.isCancelled else { return }
            self.slices = slices
            self.isScanning = false
            self.lastScan = Date()
        }
    }

    // MARK: - Actions

    /// Moves the selected items to the Trash and forgets them.
    func trashSelection() -> Int {
        var trashed: Set<URL> = []
        for url in selection {
            if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil {
                trashed.insert(url)
            }
        }
        largeFiles.removeAll { trashed.contains($0.url) }
        developerCaches.removeAll { trashed.contains($0.url) }
        installers.removeAll { trashed.contains($0.url) }
        selection.subtract(trashed)
        disk = Self.startupDisk()
        return trashed.count
    }

    /// Keeps the most recent copy of each duplicate and moves the others to the Trash.
    func trashDuplicates() -> Int {
        let extras = DuplicateFinder.extraCopies(in: duplicateGroups)
        var count = 0
        for item in extras where (try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)) != nil {
            count += 1
        }
        duplicateGroups = []
        disk = Self.startupDisk()
        return count
    }

    /// Deletes everything in the Trash for good.
    func emptyTrash() {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        let contents = (try? FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil)) ?? []
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
        trashBytes = 0
        trashCount = 0
        disk = Self.startupDisk()
    }

    // MARK: - Measuring, off the main thread

    nonisolated private static func readFolder(_ url: URL) async -> [FileItem] {
        (try? DirectoryReader().items(in: url)) ?? []
    }

    nonisolated private static func measureDeveloperCaches(home: URL, nodeModules: [URL]) async -> [SpaceCandidate] {
        let fileManager = FileManager.default
        var paths: [(URL, String)] = [
            (home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), String(localized: "Rebuilt automatically the next time you build")),
            (home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"), String(localized: "Simulator caches")),
            (home.appendingPathComponent("Library/Caches/Homebrew"), String(localized: "Homebrew downloads")),
            (home.appendingPathComponent(".npm/_cacache"), String(localized: "npm cache")),
            (home.appendingPathComponent("Library/Caches/Yarn"), String(localized: "Yarn cache")),
            (home.appendingPathComponent(".gradle/caches"), String(localized: "Gradle cache")),
            (home.appendingPathComponent("Library/Caches/pip"), String(localized: "pip cache")),
            (home.appendingPathComponent("Library/Caches/CocoaPods"), String(localized: "CocoaPods cache")),
        ]
        // Only the outermost node_modules of each project, outside Library.
        let modules = nodeModules
            .filter { !$0.path.contains("/Library/") }
            .filter { url in !url.deletingLastPathComponent().path.contains("/node_modules") }
        for module in modules {
            paths.append((module, String(localized: "Reinstalled with npm install")))
        }

        var candidates: [SpaceCandidate] = []
        for (url, detail) in paths where fileManager.fileExists(atPath: url.path) {
            if Task.isCancelled { break }
            let bytes = FolderSizer.measure(url).bytes
            guard bytes > 10_000_000 else { continue }
            let title = url.lastPathComponent == "node_modules"
                ? "node_modules · \(url.deletingLastPathComponent().lastPathComponent)"
                : url.lastPathComponent
            candidates.append(SpaceCandidate(url: url, title: title, detail: detail, bytes: bytes))
        }
        return candidates.sorted { $0.bytes > $1.bytes }
    }

    nonisolated private static func findDuplicates(home: URL) async -> [[FileItem]] {
        let folders = [URL.downloadsDirectory, URL.desktopDirectory, URL.documentsDirectory]
        var items: [FileItem] = []
        for folder in folders {
            items += collectFiles(in: folder, maxDepth: 3, minimumSize: 1_000_000)
        }
        return Array(DuplicateFinder.duplicateGroups(in: items).prefix(30))
    }

    nonisolated private static func collectFiles(in folder: URL, maxDepth: Int, minimumSize: Int64) -> [FileItem] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }
        var items: [FileItem] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            if enumerator.level >= maxDepth { enumerator.skipDescendants() }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true, Int64(values?.fileSize ?? 0) >= minimumSize else { continue }
            items.append(FileItem(contentsOf: url))
        }
        return items
    }

    nonisolated private static func measureTrash() async -> FolderSizer.Measurement? {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        guard (try? FileManager.default.contentsOfDirectory(atPath: trash.path)) != nil else { return nil }
        return FolderSizer.measure(trash)
    }

    nonisolated private static func measureSlices(home: URL, developerBytes: Int64) async -> [SpaceSlice] {
        func size(_ urls: [URL]) -> Int64 {
            urls.reduce(0) { $0 + FolderSizer.measure($1).bytes }
        }
        return [
            SpaceSlice(id: "apps", title: String(localized: "Applications"), bytes: size([URL(fileURLWithPath: "/Applications")]), tint: .documents),
            SpaceSlice(id: "documents", title: String(localized: "Documents"), bytes: size([.documentsDirectory, .desktopDirectory, .downloadsDirectory]), tint: .images),
            SpaceSlice(id: "media", title: String(localized: "Photos and videos"), bytes: size([.picturesDirectory, .moviesDirectory, .musicDirectory]), tint: .videos),
            SpaceSlice(id: "developer", title: String(localized: "Development"), bytes: developerBytes, tint: .code),
        ]
    }

    private static func startupDisk() -> DiskUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? home.resourceValues(forKeys: keys), let total = values.volumeTotalCapacity else { return nil }
        let name = (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeLocalizedNameKey]))?.volumeLocalizedName
        return DiskUsage(
            name: name ?? "Macintosh HD",
            availableBytes: values.volumeAvailableCapacityForImportantUsage ?? 0,
            totalBytes: Int64(total)
        )
    }

    private static func usageDetail(for hit: Spotlight.Hit) -> String {
        let folder = FileManager.default.displayName(atPath: hit.url.deletingLastPathComponent().path)
        guard let lastUsed = hit.lastUsed else {
            return String(localized: "\(folder) · never opened")
        }
        let relative = lastUsed.formatted(.relative(presentation: .named))
        return String(localized: "\(folder) · opened \(relative)")
    }
}
