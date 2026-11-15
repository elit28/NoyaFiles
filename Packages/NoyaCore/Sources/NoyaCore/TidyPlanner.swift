import Foundation

/// A kind of file the Downloads tidy-up knows how to put away.
public enum TidyRuleKind: String, Codable, CaseIterable, Sendable {
    /// Installers whose app is already installed. They go to the Trash.
    case installedInstallers
    case screenshots
    case images
    case pdfs
    case documents
    case videos
    case audio
    case archives
    /// Files with no activity for a long time, whatever their kind.
    case staleFiles

    /// The order in which rules get a chance to claim a file.
    public static let priority: [TidyRuleKind] = [
        .installedInstallers, .screenshots, .images, .pdfs, .documents, .videos, .audio, .archives, .staleFiles,
    ]
}

/// One rule of the tidy-up: what it moves, and where.
public struct TidyRule: Codable, Hashable, Sendable, Identifiable {
    public var kind: TidyRuleKind
    public var isEnabled: Bool
    /// Where matching files go, or `nil` for the Trash.
    public var destination: URL?

    public var id: TidyRuleKind { kind }

    public init(kind: TidyRuleKind, isEnabled: Bool, destination: URL?) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.destination = destination
    }
}

/// A file the tidy-up will move, and where to.
public struct TidyMove: Hashable, Sendable {
    public let item: FileItem
    public let rule: TidyRuleKind
    /// The destination folder, or `nil` for the Trash.
    public let destination: URL?
}

/// What a tidy-up would do, before it does anything.
public struct TidyPlan: Sendable, Equatable {
    public let moves: [TidyMove]
    /// Loose files that no rule claims.
    public let remainingCount: Int

    public func moves(for rule: TidyRuleKind) -> [TidyMove] {
        moves.filter { $0.rule == rule }
    }

    public func bytes(for rule: TidyRuleKind) -> Int64 {
        moves(for: rule).reduce(0) { $0 + $1.item.size }
    }

    public var totalBytes: Int64 {
        moves.reduce(0) { $0 + $1.item.size }
    }
}

public enum TidyPlanner {
    /// Decides where each loose file of a folder should go. Nothing is moved.
    ///
    /// Hidden files, folders and packages stay where they are, as do files already
    /// inside their destination.
    public static func plan(
        for items: [FileItem],
        rules: [TidyRule],
        installedAppNames: [String],
        now: Date,
        staleAfterDays: Int = CleanupAdvisor.defaultStaleDays
    ) -> TidyPlan {
        let enabled = Dictionary(uniqueKeysWithValues: rules.filter(\.isEnabled).map { ($0.kind, $0) })
        var moves: [TidyMove] = []
        var remaining = 0

        for item in items where item.kind == .file && !item.isHidden {
            let claimed = TidyRuleKind.priority.first { kind in
                guard enabled[kind] != nil else { return false }
                return matches(kind, item, installedAppNames: installedAppNames, now: now, staleAfterDays: staleAfterDays)
            }
            guard let kind = claimed, let rule = enabled[kind] else {
                remaining += 1
                continue
            }
            if let destination = rule.destination,
               item.url.deletingLastPathComponent().standardizedFileURL.path == destination.standardizedFileURL.path {
                remaining += 1
                continue
            }
            moves.append(TidyMove(item: item, rule: kind, destination: rule.destination))
        }
        return TidyPlan(moves: moves, remainingCount: remaining)
    }

    static func matches(
        _ kind: TidyRuleKind,
        _ item: FileItem,
        installedAppNames: [String],
        now: Date,
        staleAfterDays: Int
    ) -> Bool {
        switch kind {
        case .installedInstallers:
            return item.category == .installers
                && InstalledAppMatcher.installedApp(forInstaller: item.name, among: installedAppNames) != nil
        case .screenshots: return item.category == .screenshots
        case .images: return item.category == .images
        case .pdfs: return item.category == .pdfs
        case .documents: return item.category == .documents
        case .videos: return item.category == .videos
        case .audio: return item.category == .audio
        case .archives: return item.category == .archives
        case .staleFiles: return item.isStale(olderThan: staleAfterDays, now: now)
        }
    }
}
