import Foundation

/// A summary of what takes up space in a folder.
public struct FolderInsights: Sendable, Equatable {
    public struct Entry: Sendable, Equatable, Identifiable {
        public enum Subject: Sendable, Hashable {
            /// A subfolder, measured recursively.
            case folder(URL, name: String)
            /// All loose files of one category.
            case category(FileCategory)
        }

        public let subject: Subject
        public let bytes: Int64
        /// Files inside the folder, or loose files in the category.
        public let fileCount: Int

        public var id: Subject { subject }

        public init(subject: Subject, bytes: Int64, fileCount: Int) {
            self.subject = subject
            self.bytes = bytes
            self.fileCount = fileCount
        }
    }

    public let totalBytes: Int64
    public let folderCount: Int
    /// Files and packages sitting directly in the folder.
    public let looseFileCount: Int
    /// Subfolders and categories, largest first.
    public let entries: [Entry]
    public let hiddenBytes: Int64
    public let hiddenItemCount: Int
    /// Folders and packages whose size is not known yet.
    public let unmeasuredCount: Int

    /// Builds the summary of a folder from its entries.
    ///
    /// - Parameters:
    ///   - items: The direct contents of the folder, hidden entries included.
    ///   - measurements: Known sizes of the folders and packages among `items`.
    ///   - includeHidden: Whether hidden entries count towards the totals and entries.
    public init(items: [FileItem], measurements: [URL: FolderSizer.Measurement], includeHidden: Bool) {
        var totalBytes: Int64 = 0
        var folderCount = 0
        var looseFileCount = 0
        var hiddenBytes: Int64 = 0
        var hiddenItemCount = 0
        var unmeasuredCount = 0
        var entries: [Entry] = []
        var categoryTotals: [FileCategory: (bytes: Int64, count: Int)] = [:]

        for item in items {
            let measurement = measurements[item.url]
            if item.isContainer && measurement == nil {
                unmeasuredCount += 1
            }
            let bytes = item.isContainer ? (measurement?.bytes ?? 0) : item.size

            if item.isHidden {
                hiddenBytes += bytes
                hiddenItemCount += 1
                if !includeHidden { continue }
            }

            totalBytes += bytes
            if item.isFolder {
                folderCount += 1
                entries.append(Entry(
                    subject: .folder(item.url, name: item.name),
                    bytes: bytes,
                    fileCount: measurement?.fileCount ?? 0
                ))
            } else {
                looseFileCount += 1
                let category = item.category ?? .other
                categoryTotals[category, default: (0, 0)].bytes += bytes
                categoryTotals[category, default: (0, 0)].count += 1
            }
        }

        entries += categoryTotals.map { category, total in
            Entry(subject: .category(category), bytes: total.bytes, fileCount: total.count)
        }
        entries.sort { lhs, rhs in
            if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
            return lhs.subject.sortKey < rhs.subject.sortKey
        }

        self.totalBytes = totalBytes
        self.folderCount = folderCount
        self.looseFileCount = looseFileCount
        self.entries = entries
        self.hiddenBytes = hiddenBytes
        self.hiddenItemCount = hiddenItemCount
        self.unmeasuredCount = unmeasuredCount
    }
}

private extension FolderInsights.Entry.Subject {
    /// Keeps the order stable when two entries have the same size.
    var sortKey: String {
        switch self {
        case .folder(_, let name): "0-" + name.lowercased()
        case .category(let category): "1-" + category.rawValue
        }
    }
}
