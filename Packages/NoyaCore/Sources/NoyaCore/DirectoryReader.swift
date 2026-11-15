import Foundation

/// Lists the direct contents of a folder.
public struct DirectoryReader: Sendable {
    public init() {}

    /// Returns every entry of `directory`, hidden ones included, in no particular order.
    ///
    /// - Throws: The underlying file system error, for example when the folder
    ///   does not exist or the app is not allowed to read it.
    public func items(in directory: URL) throws -> [FileItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Self.resourceKeys,
            options: []
        )
        return urls.map(FileItem.init(contentsOf:))
    }

    static var resourceKeys: [URLResourceKey] {
        var keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isHiddenKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
        ]
        #if canImport(Darwin)
        keys += [.isPackageKey, .addedToDirectoryDateKey]
        #endif
        return keys
    }
}
