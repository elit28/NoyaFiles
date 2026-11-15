import Foundation

/// A group of files the user may want to review and remove.
public struct CleanupSuggestion: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Hashable {
        /// Disk images and installer packages.
        case installers
        /// Files with no activity for the given number of days.
        case staleFiles(days: Int)
    }

    public let kind: Kind
    public let itemURLs: [URL]
    public let bytes: Int64

    public var id: Kind { kind }
    public var count: Int { itemURLs.count }

    public init(kind: Kind, itemURLs: [URL], bytes: Int64) {
        self.kind = kind
        self.itemURLs = itemURLs
        self.bytes = bytes
    }
}

/// Looks for files that are likely safe to clean up. It only suggests; it never deletes.
public enum CleanupAdvisor {
    public static let defaultStaleDays = 90

    public static func suggestions(
        for items: [FileItem],
        now: Date,
        staleAfterDays: Int = defaultStaleDays
    ) -> [CleanupSuggestion] {
        let looseFiles = items.filter { !$0.isFolder && !$0.isHidden }
        var suggestions: [CleanupSuggestion] = []

        let installers = looseFiles.filter { $0.kind == .file && $0.category == .installers }
        if !installers.isEmpty {
            suggestions.append(CleanupSuggestion(
                kind: .installers,
                itemURLs: installers.map(\.url),
                bytes: installers.reduce(0) { $0 + $1.size }
            ))
        }

        let staleFiles = looseFiles.filter { $0.kind == .file && $0.isStale(olderThan: staleAfterDays, now: now) }
        if !staleFiles.isEmpty {
            suggestions.append(CleanupSuggestion(
                kind: .staleFiles(days: staleAfterDays),
                itemURLs: staleFiles.map(\.url),
                bytes: staleFiles.reduce(0) { $0 + $1.size }
            ))
        }

        return suggestions
    }
}
