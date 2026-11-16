import Foundation
import NoyaCore
import Observation
import SwiftUI

struct WorkspaceCollection: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
}

/// A file or folder gathered in a workspace. The original stays where it is.
struct WorkspaceEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Lets the entry follow its file when it is moved or renamed.
    var bookmark: Data?
    var path: String
    var collectionID: UUID?
    var isPinned = false
    var addedAt = Date()
    /// The rule that added the entry, if any.
    var ruleID: UUID?

    init(url: URL, collectionID: UUID?, ruleID: UUID? = nil) {
        bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        path = url.path
        self.collectionID = collectionID
        self.ruleID = ruleID
    }

    /// The file's current location, or `nil` when it no longer exists.
    func resolvedURL() -> URL? {
        if let bookmark {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale),
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
}

/// Adds matching files to a workspace automatically.
struct WorkspaceRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var condition: RuleCondition
    var collectionID: UUID?
    var isEnabled = true
    var matchCount = 0
    var lastMatchAt: Date?
}

enum WorkspaceColor: String, Codable, CaseIterable, Identifiable {
    case teal, blue, purple, green, orange, pink, gray

    var id: Self { self }

    var color: Color {
        switch self {
        case .teal: Color(hex: 0x14B8A6)
        case .blue: Color(hex: 0x3B82F6)
        case .purple: Color(hex: 0x8B5CF6)
        case .green: Color(hex: 0x10B981)
        case .orange: Color(hex: 0xF59E0B)
        case .pink: Color(hex: 0xEC4899)
        case .gray: Color(hex: 0x6B7280)
        }
    }
}

/// A set of files from anywhere on the Mac, gathered around a project or a topic.
struct Workspace: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var summary = ""
    var color: WorkspaceColor = .teal
    var collections: [WorkspaceCollection] = []
    var entries: [WorkspaceEntry] = []
    var rules: [WorkspaceRule] = []

    func collection(_ id: UUID?) -> WorkspaceCollection? {
        collections.first { $0.id == id }
    }
}

/// A file found while applying smart rules, with its Finder tags.
struct RuleCandidate: Sendable {
    let item: FileItem
    let tags: [String]
}

/// Every workspace, saved in Application Support and shared by all windows.
@MainActor
@Observable
final class WorkspaceStore {
    static let shared = WorkspaceStore()

    private(set) var workspaces: [Workspace] = []
    var lastError: String?

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var rulesTask: Task<Void, Never>?

    init(fileURL: URL = WorkspaceStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
        rulesTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.applyRules()
                try? await Task.sleep(for: .seconds(600))
            }
        }
    }

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("NOYA Files", isDirectory: true)
            .appendingPathComponent("workspaces.json")
    }

    func workspace(_ id: UUID) -> Workspace? {
        workspaces.first { $0.id == id }
    }

    // MARK: - Workspaces

    @discardableResult
    func createWorkspace(name: String, summary: String, color: WorkspaceColor) -> UUID {
        let workspace = Workspace(name: name, summary: summary, color: color)
        workspaces.append(workspace)
        save()
        return workspace.id
    }

    func update(_ workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index] = workspace
        save()
    }

    func deleteWorkspace(_ id: UUID) {
        workspaces.removeAll { $0.id == id }
        save()
    }

    // MARK: - Entries

    /// Adds files to a workspace, skipping those already in it.
    func add(_ urls: [URL], to workspaceID: UUID, collection collectionID: UUID? = nil) {
        modify(workspaceID) { workspace in
            let existing = Set(workspace.entries.map(\.path))
            for url in urls where !existing.contains(url.path) {
                workspace.entries.append(WorkspaceEntry(url: url, collectionID: collectionID))
            }
        }
    }

    func remove(_ entryIDs: Set<UUID>, from workspaceID: UUID) {
        modify(workspaceID) { $0.entries.removeAll { entryIDs.contains($0.id) } }
    }

    func setPinned(_ isPinned: Bool, _ entryIDs: Set<UUID>, in workspaceID: UUID) {
        modify(workspaceID) { workspace in
            for index in workspace.entries.indices where entryIDs.contains(workspace.entries[index].id) {
                workspace.entries[index].isPinned = isPinned
            }
        }
    }

    func move(_ entryIDs: Set<UUID>, toCollection collectionID: UUID?, in workspaceID: UUID) {
        modify(workspaceID) { workspace in
            for index in workspace.entries.indices where entryIDs.contains(workspace.entries[index].id) {
                workspace.entries[index].collectionID = collectionID
            }
        }
    }

    // MARK: - Collections

    @discardableResult
    func addCollection(named name: String, to workspaceID: UUID) -> UUID {
        let collection = WorkspaceCollection(name: name)
        modify(workspaceID) { $0.collections.append(collection) }
        return collection.id
    }

    func removeCollection(_ collectionID: UUID, from workspaceID: UUID) {
        modify(workspaceID) { workspace in
            workspace.collections.removeAll { $0.id == collectionID }
            for index in workspace.entries.indices where workspace.entries[index].collectionID == collectionID {
                workspace.entries[index].collectionID = nil
            }
            for index in workspace.rules.indices where workspace.rules[index].collectionID == collectionID {
                workspace.rules[index].collectionID = nil
            }
        }
    }

    // MARK: - Rules

    func addRule(_ rule: WorkspaceRule, to workspaceID: UUID) {
        modify(workspaceID) { $0.rules.append(rule) }
        Task { await applyRules() }
    }

    func setRule(_ ruleID: UUID, enabled: Bool, in workspaceID: UUID) {
        modify(workspaceID) { workspace in
            if let index = workspace.rules.firstIndex(where: { $0.id == ruleID }) {
                workspace.rules[index].isEnabled = enabled
            }
        }
        if enabled { Task { await applyRules() } }
    }

    func removeRule(_ ruleID: UUID, from workspaceID: UUID) {
        modify(workspaceID) { $0.rules.removeAll { $0.id == ruleID } }
    }

    /// Looks through Downloads, Desktop and Documents for files matching enabled rules.
    func applyRules() async {
        guard workspaces.contains(where: { $0.rules.contains(where: \.isEnabled) }) else { return }
        let candidates = await Self.scanCandidates()
        let now = Date()
        var changed = false

        for workspaceIndex in workspaces.indices {
            var workspace = workspaces[workspaceIndex]
            var known = Set(workspace.entries.map(\.path))
            for ruleIndex in workspace.rules.indices where workspace.rules[ruleIndex].isEnabled {
                let rule = workspace.rules[ruleIndex]
                let matches = candidates.filter { !known.contains($0.item.url.path) && rule.condition.matches($0.item, tags: $0.tags) }
                guard !matches.isEmpty else { continue }
                for match in matches {
                    workspace.entries.append(WorkspaceEntry(url: match.item.url, collectionID: rule.collectionID, ruleID: rule.id))
                    known.insert(match.item.url.path)
                }
                workspace.rules[ruleIndex].matchCount += matches.count
                workspace.rules[ruleIndex].lastMatchAt = now
                changed = true
            }
            workspaces[workspaceIndex] = workspace
        }
        if changed { save() }
    }

    nonisolated private static func scanCandidates() async -> [RuleCandidate] {
        collectCandidates()
    }

    /// Directory enumerators cannot be iterated from asynchronous code, hence this synchronous helper.
    nonisolated private static func collectCandidates() -> [RuleCandidate] {
        let fileManager = FileManager.default
        let folders: [(url: URL, depth: Int)] = [
            (.downloadsDirectory, 1),
            (.desktopDirectory, 1),
            (.documentsDirectory, 3),
        ]
        var candidates: [RuleCandidate] = []
        let keys: [URLResourceKey] = [.tagNamesKey]
        for folder in folders {
            guard let enumerator = fileManager.enumerator(
                at: folder.url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let url as URL in enumerator {
                if Task.isCancelled { return candidates }
                if enumerator.level >= folder.depth { enumerator.skipDescendants() }
                let item = FileItem(contentsOf: url)
                guard !item.isFolder else { continue }
                let tags = (try? url.resourceValues(forKeys: Set(keys)))?.tagNames ?? []
                candidates.append(RuleCandidate(item: item, tags: tags))
            }
        }
        return candidates
    }

    // MARK: - Saving

    private func modify(_ workspaceID: UUID, _ change: (inout Workspace) -> Void) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        change(&workspaces[index])
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            workspaces = try JSONDecoder().decode([Workspace].self, from: data)
        } catch {
            lastError = String(localized: "Your workspaces could not be read: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(workspaces).write(to: fileURL, options: .atomic)
        } catch {
            lastError = String(localized: "Your workspaces could not be saved: \(error.localizedDescription)")
        }
    }
}
