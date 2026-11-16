import Foundation

/// A snapshot of one entry in a folder.
public struct FileItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        /// A regular folder the user can browse into.
        case folder
        /// A folder the system presents as a single file, such as an `.app` bundle.
        case package
        /// A regular file.
        case file
    }

    public let url: URL
    public let name: String
    public let kind: Kind
    public let isHidden: Bool
    /// Logical size in bytes. Always zero for folders and packages, whose size must be measured.
    public let size: Int64
    public let modificationDate: Date?
    public let creationDate: Date?
    /// When the item arrived in its folder. Only available on Apple platforms.
    public let addedDate: Date?
    /// The category of a file or package, or `nil` for a folder.
    public let category: FileCategory?

    public var id: URL { url }
    public var isFolder: Bool { kind == .folder }
    public var isContainer: Bool { kind != .file }
    public var fileExtension: String { FileCategory.pathExtension(of: name) }

    /// The most recent moment the item arrived in, or changed within, its folder.
    public var lastActivityDate: Date? {
        [addedDate, modificationDate].compactMap { $0 }.max() ?? creationDate
    }

    public init(
        url: URL,
        name: String? = nil,
        kind: Kind,
        isHidden: Bool = false,
        size: Int64 = 0,
        modificationDate: Date? = nil,
        creationDate: Date? = nil,
        addedDate: Date? = nil
    ) {
        let resolvedName = name ?? url.lastPathComponent
        self.url = url
        self.name = resolvedName
        self.kind = kind
        self.isHidden = isHidden
        self.size = kind == .file ? size : 0
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.addedDate = addedDate
        self.category = kind == .folder ? nil : FileCategory.classify(fileName: resolvedName)
    }

    /// Whether the item has seen no activity for more than `days` days. Folders are never stale.
    public func isStale(olderThan days: Int, now: Date) -> Bool {
        guard !isFolder, let lastActivityDate else { return false }
        return now.timeIntervalSince(lastActivityDate) > TimeInterval(days) * 86_400
    }
}

extension FileItem {
    /// Reads an item's metadata from the file system.
    ///
    /// Metadata that cannot be read falls back to neutral defaults, so a single
    /// unreadable entry never prevents a folder from being listed.
    public init(contentsOf url: URL) {
        let values = try? url.resourceValues(forKeys: Set(DirectoryReader.resourceKeys))
        let name = url.lastPathComponent

        var isDirectory = values?.isDirectory ?? false
        if values?.isSymbolicLink == true {
            let target = url.resolvingSymlinksInPath()
            isDirectory = (try? target.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        }

        #if canImport(Darwin)
        let isPackage = values?.isPackage ?? false
        let addedDate = values?.addedToDirectoryDate
        #else
        let isPackage = url.pathExtension.lowercased() == "app"
        let addedDate: Date? = nil
        #endif

        let kind: Kind = isDirectory ? (isPackage ? .package : .folder) : .file
        self.init(
            url: url,
            name: name,
            kind: kind,
            isHidden: name.hasPrefix(".") || values?.isHidden == true,
            size: Int64(values?.fileSize ?? 0),
            modificationDate: values?.contentModificationDate,
            creationDate: values?.creationDate,
            addedDate: addedDate
        )
    }
}
