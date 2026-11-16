import Foundation

/// Calls back on the main thread whenever entries are added to, removed from
/// or renamed in a folder. Watching stops when the watcher is released.
final class DirectoryWatcher {
    let url: URL
    private let source: any DispatchSourceFileSystemObject

    init?(url: URL, onChange: @escaping @MainActor @Sendable () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .link],
            queue: .main
        )
        source.setEventHandler {
            MainActor.assumeIsolated { onChange() }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()

        self.url = url
        self.source = source
    }

    deinit {
        source.cancel()
    }
}
