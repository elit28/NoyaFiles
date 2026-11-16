import Foundation

/// A group of files the user may want to review and remove.
public struct CleanupSuggestion: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Hashable {
        /// Disk images and installer packages.
        case installers
        /// Files with no activity for the given number of days.
        case staleFiles(days: Int)
    }

    /// An installer whose app is already installed.
    public struct InstalledMatch: Sendable, Equatable {
        public let installerURL: URL
        public let appName: String
        public let bytes: Int64

        public init(installerURL: URL, appName: String, bytes: Int64) {
            self.installerURL = installerURL
            self.appName = appName
            self.bytes = bytes
        }
    }

    public let kind: Kind
    public let itemURLs: [URL]
    public let bytes: Int64
    /// For installers: the ones whose app is already installed.
    public let installedMatches: [InstalledMatch]

    public var id: Kind { kind }
    public var count: Int { itemURLs.count }

    public init(kind: Kind, itemURLs: [URL], bytes: Int64, installedMatches: [InstalledMatch] = []) {
        self.kind = kind
        self.itemURLs = itemURLs
        self.bytes = bytes
        self.installedMatches = installedMatches
    }
}

/// Looks for files that are likely safe to clean up. It only suggests; it never deletes.
public enum CleanupAdvisor {
    public static let defaultStaleDays = 90

    /// - Parameter installedAppNames: Names of installed apps, used to spot installers that are no longer needed.
    public static func suggestions(
        for items: [FileItem],
        now: Date,
        staleAfterDays: Int = defaultStaleDays,
        installedAppNames: [String] = []
    ) -> [CleanupSuggestion] {
        let looseFiles = items.filter { !$0.isFolder && !$0.isHidden }
        var suggestions: [CleanupSuggestion] = []

        let installers = looseFiles.filter { $0.kind == .file && $0.category == .installers }
        if !installers.isEmpty {
            let matches = installers.compactMap { installer -> CleanupSuggestion.InstalledMatch? in
                guard let app = InstalledAppMatcher.installedApp(forInstaller: installer.name, among: installedAppNames) else {
                    return nil
                }
                return CleanupSuggestion.InstalledMatch(installerURL: installer.url, appName: app, bytes: installer.size)
            }
            suggestions.append(CleanupSuggestion(
                kind: .installers,
                itemURLs: installers.map(\.url),
                bytes: installers.reduce(0) { $0 + $1.size },
                installedMatches: matches
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
