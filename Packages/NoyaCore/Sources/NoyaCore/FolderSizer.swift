import Foundation

/// Measures how much space a folder or package takes, including everything inside it.
public enum FolderSizer {
    public struct Measurement: Hashable, Sendable {
        /// Sum of the logical sizes of every file inside, at any depth.
        public var bytes: Int64
        /// Number of regular files inside, at any depth.
        public var fileCount: Int
        /// Number of visible entries directly inside.
        public var itemCount: Int

        public init(bytes: Int64, fileCount: Int, itemCount: Int) {
            self.bytes = bytes
            self.fileCount = fileCount
            self.itemCount = itemCount
        }
    }

    /// Walks `url` recursively and adds up the size of its files.
    ///
    /// Symbolic links are not followed, other volumes mounted inside the folder are
    /// not entered, and unreadable entries are skipped. When the current task is
    /// cancelled, the walk stops and returns what it has counted so far.
    public static func measure(_ url: URL) -> Measurement {
        let fileManager = FileManager.default
        #if canImport(Darwin)
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isVolumeKey]
        #else
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        #endif
        let keySet = Set(keys)
        var bytes: Int64 = 0
        var fileCount = 0

        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) {
            for case let fileURL as URL in enumerator {
                if Task.isCancelled { break }
                guard let values = try? fileURL.resourceValues(forKeys: keySet) else { continue }
                #if canImport(Darwin)
                if values.isVolume == true {
                    enumerator.skipDescendants()
                    continue
                }
                #endif
                guard values.isRegularFile == true else { continue }
                bytes += Int64(values.fileSize ?? 0)
                fileCount += 1
            }
        }

        let directNames = (try? fileManager.contentsOfDirectory(atPath: url.path)) ?? []
        let itemCount = directNames.filter { !$0.hasPrefix(".") }.count
        return Measurement(bytes: bytes, fileCount: fileCount, itemCount: itemCount)
    }
}
