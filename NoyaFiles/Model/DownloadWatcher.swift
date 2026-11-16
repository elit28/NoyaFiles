import Foundation

/// Notices files that arrive in Downloads, so the app can offer to show them.
@MainActor
final class DownloadWatcher {
    static let shared = DownloadWatcher()

    /// Called with each finished download. The last window to set it receives the downloads.
    var onNewDownload: (@MainActor (URL) -> Void)?

    private var watcher: DirectoryWatcher?
    private var known: Set<String> = []
    private var checkTask: Task<Void, Never>?
    private let folder = URL.downloadsDirectory

    /// Extensions of files that browsers are still writing.
    private static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial", "tmp", "opdownload"]

    func start() {
        guard watcher == nil else { return }
        known = Set(names())
        watcher = DirectoryWatcher(url: folder) { [weak self] in
            self?.scheduleCheck()
        }
    }

    private func scheduleCheck() {
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            // Lets the browser finish renaming the file from its temporary name.
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    private func check() {
        let current = Set(names())
        let added = current.subtracting(known)
        known = current
        guard UserDefaults.standard.object(forKey: PreferenceKey.notifyDownloads) as? Bool ?? true else { return }

        let finished = added
            .filter { !$0.hasPrefix(".") && !Self.partialExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .map { folder.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if let newest = finished.last {
            onNewDownload?(newest)
        }
    }

    private func names() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }
}
