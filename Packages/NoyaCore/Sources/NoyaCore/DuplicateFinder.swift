import Foundation

/// Finds files with exactly the same contents.
public enum DuplicateFinder {
    /// Groups files whose contents are identical, largest groups of bytes first.
    ///
    /// Only regular, non-empty files are compared. Files are first grouped by size,
    /// then compared byte by byte, so nothing is read unless two files have the same size.
    /// Stops early, returning what it has found, when the current task is cancelled.
    public static func duplicateGroups(in items: [FileItem]) -> [[FileItem]] {
        var bySize: [Int64: [FileItem]] = [:]
        for item in items where item.kind == .file && item.size > 0 {
            bySize[item.size, default: []].append(item)
        }

        var groups: [[FileItem]] = []
        for (_, candidates) in bySize where candidates.count > 1 {
            if Task.isCancelled { break }
            var remaining = candidates
            while remaining.count > 1 {
                let reference = remaining.removeFirst()
                var group = [reference]
                var others: [FileItem] = []
                for candidate in remaining {
                    if haveSameContents(reference.url, candidate.url) {
                        group.append(candidate)
                    } else {
                        others.append(candidate)
                    }
                }
                if group.count > 1 { groups.append(group) }
                remaining = others
            }
        }

        return groups.sorted { lhs, rhs in
            let lhsBytes = lhs[0].size * Int64(lhs.count - 1)
            let rhsBytes = rhs[0].size * Int64(rhs.count - 1)
            if lhsBytes != rhsBytes { return lhsBytes > rhsBytes }
            return lhs[0].name < rhs[0].name
        }
    }

    /// The bytes freed by keeping one file of each group.
    public static func reclaimableBytes(in groups: [[FileItem]]) -> Int64 {
        groups.reduce(0) { $0 + $1[0].size * Int64($1.count - 1) }
    }

    /// The files to remove so that only the most recently changed copy of each group remains.
    public static func extraCopies(in groups: [[FileItem]]) -> [FileItem] {
        groups.flatMap { group -> [FileItem] in
            let keeper = group.max { ($0.lastActivityDate ?? .distantPast) < ($1.lastActivityDate ?? .distantPast) }
            return group.filter { $0.url != keeper?.url }
        }
    }

    static func haveSameContents(_ lhs: URL, _ rhs: URL) -> Bool {
        guard
            let left = try? FileHandle(forReadingFrom: lhs),
            let right = try? FileHandle(forReadingFrom: rhs)
        else { return false }
        defer {
            try? left.close()
            try? right.close()
        }

        let chunkSize = 256 * 1024
        while true {
            let leftChunk = (try? left.read(upToCount: chunkSize)) ?? Data()
            let rightChunk = (try? right.read(upToCount: chunkSize)) ?? Data()
            if leftChunk != rightChunk { return false }
            if leftChunk.isEmpty { return true }
        }
    }
}

/// Files of one format, such as all the PNG images in a folder.
public struct FormatGroup: Sendable, Equatable, Identifiable {
    /// The uppercased extension, such as `PNG`, or an empty string for files without one.
    public let format: String
    public let count: Int
    public let bytes: Int64

    public var id: String { format }
}

extension Grouping {
    /// Groups files by extension, largest group first.
    public static func byFormat(_ items: [FileItem]) -> [FormatGroup] {
        var totals: [String: (count: Int, bytes: Int64)] = [:]
        for item in items where !item.isFolder {
            totals[item.fileExtension.uppercased(), default: (0, 0)].count += 1
            totals[item.fileExtension.uppercased(), default: (0, 0)].bytes += item.size
        }
        return totals
            .map { FormatGroup(format: $0.key, count: $0.value.count, bytes: $0.value.bytes) }
            .sorted { lhs, rhs in
                if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
                return lhs.format < rhs.format
            }
    }
}
