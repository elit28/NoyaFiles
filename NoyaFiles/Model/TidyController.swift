import Foundation
import NoyaCore
import Observation

/// Where a file went during a tidy-up, so it can be put back.
struct TidyRecord: Sendable {
    let original: URL
    let current: URL
}

struct TidyOutcome: Sendable {
    let records: [TidyRecord]
    let failures: [String]
}

/// Puts the Downloads folder in order, following rules the user can change.
@MainActor
@Observable
final class TidyController {
    static let shared = TidyController()

    private static let rulesKey = "tidy.rules"
    private static let autoWeeklyKey = "tidy.autoWeekly"
    private static let showsPreviewKey = "tidy.showsPreview"
    private static let lastRunKey = "tidy.lastRun"

    var rules: [TidyRule] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(rules), forKey: Self.rulesKey) }
    }

    var tidiesWeekly: Bool {
        didSet { UserDefaults.standard.set(tidiesWeekly, forKey: Self.autoWeeklyKey) }
    }

    var showsPreview: Bool {
        didSet { UserDefaults.standard.set(showsPreview, forKey: Self.showsPreviewKey) }
    }

    private(set) var lastRun: Date?
    private(set) var lastOutcome: TidyOutcome?

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.rulesKey),
           let stored = try? JSONDecoder().decode([TidyRule].self, from: data) {
            rules = Self.completed(stored)
        } else {
            rules = Self.defaultRules
        }
        tidiesWeekly = defaults.bool(forKey: Self.autoWeeklyKey)
        showsPreview = defaults.object(forKey: Self.showsPreviewKey) as? Bool ?? true
        lastRun = defaults.object(forKey: Self.lastRunKey) as? Date
    }

    /// Whether the weekly tidy-up is due.
    var isWeeklyTidyDue: Bool {
        guard tidiesWeekly else { return false }
        guard let lastRun else { return true }
        return Date().timeIntervalSince(lastRun) >= 7 * 86_400
    }

    func rule(_ kind: TidyRuleKind) -> TidyRule? {
        rules.first { $0.kind == kind }
    }

    func setRule(_ kind: TidyRuleKind, enabled: Bool) {
        guard let index = rules.firstIndex(where: { $0.kind == kind }) else { return }
        rules[index].isEnabled = enabled
    }

    func setDestination(_ url: URL, for kind: TidyRuleKind) {
        guard let index = rules.firstIndex(where: { $0.kind == kind }), kind != .installedInstallers else { return }
        rules[index].destination = url
    }

    /// What tidying the Downloads folder would do right now.
    func makePlan() async -> TidyPlan {
        let rules = self.rules
        return await Self.plan(rules: rules)
    }

    /// Moves the files of a plan, creating destination folders as needed.
    func apply(_ plan: TidyPlan) async -> TidyOutcome {
        let outcome = await Self.perform(plan.moves)
        lastOutcome = outcome
        lastRun = Date()
        UserDefaults.standard.set(lastRun, forKey: Self.lastRunKey)
        return outcome
    }

    /// Puts every file of the last tidy-up back where it was.
    func undoLastRun() async {
        guard let outcome = lastOutcome else { return }
        lastOutcome = nil
        await Self.restore(outcome.records)
    }

    // MARK: - Work done off the main thread

    nonisolated private static func plan(rules: [TidyRule]) async -> TidyPlan {
        let items = (try? DirectoryReader().items(in: .downloadsDirectory)) ?? []
        return TidyPlanner.plan(
            for: items,
            rules: rules,
            installedAppNames: InstalledAppMatcher.installedAppNames(),
            now: Date()
        )
    }

    nonisolated private static func perform(_ moves: [TidyMove]) async -> TidyOutcome {
        let fileManager = FileManager.default
        var records: [TidyRecord] = []
        var failures: [String] = []
        for move in moves {
            do {
                if let folder = move.destination {
                    try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                    let target = FileOperationCenter.uniqueDestination(for: move.item.name, in: folder)
                    try fileManager.moveItem(at: move.item.url, to: target)
                    records.append(TidyRecord(original: move.item.url, current: target))
                } else {
                    var trashed: NSURL?
                    try fileManager.trashItem(at: move.item.url, resultingItemURL: &trashed)
                    if let trashed = trashed as URL? {
                        records.append(TidyRecord(original: move.item.url, current: trashed))
                    }
                }
            } catch {
                failures.append(move.item.name)
            }
        }
        return TidyOutcome(records: records, failures: failures)
    }

    nonisolated private static func restore(_ records: [TidyRecord]) async {
        let fileManager = FileManager.default
        for record in records.reversed() where fileManager.fileExists(atPath: record.current.path) {
            let folder = record.original.deletingLastPathComponent()
            let target = FileOperationCenter.uniqueDestination(for: record.original.lastPathComponent, in: folder)
            try? fileManager.moveItem(at: record.current, to: target)
        }
    }

    // MARK: - Defaults

    static var defaultRules: [TidyRule] {
        let pictures = URL.picturesDirectory
        let documents = URL.documentsDirectory
        return [
            TidyRule(kind: .installedInstallers, isEnabled: true, destination: nil),
            TidyRule(kind: .screenshots, isEnabled: true, destination: pictures.appendingPathComponent(String(localized: "Screenshots"), isDirectory: true)),
            TidyRule(kind: .images, isEnabled: true, destination: pictures.appendingPathComponent(String(localized: "Downloaded"), isDirectory: true)),
            TidyRule(kind: .pdfs, isEnabled: true, destination: documents.appendingPathComponent("PDF", isDirectory: true)),
            TidyRule(kind: .documents, isEnabled: false, destination: documents),
            TidyRule(kind: .videos, isEnabled: false, destination: URL.moviesDirectory),
            TidyRule(kind: .audio, isEnabled: false, destination: URL.musicDirectory),
            TidyRule(kind: .archives, isEnabled: false, destination: URL.downloadsDirectory.appendingPathComponent(String(localized: "Archives"), isDirectory: true)),
            TidyRule(kind: .staleFiles, isEnabled: true, destination: URL.downloadsDirectory.appendingPathComponent(String(localized: "Archive"), isDirectory: true)),
        ]
    }

    /// Adds any rule missing from stored settings, keeping the order of `defaultRules`.
    private static func completed(_ stored: [TidyRule]) -> [TidyRule] {
        defaultRules.map { rule in stored.first { $0.kind == rule.kind } ?? rule }
    }
}

extension TidyRuleKind {
    var title: String {
        switch self {
        case .installedInstallers: String(localized: "Installers already installed")
        case .screenshots: String(localized: "Screenshots")
        case .images: String(localized: "Images")
        case .pdfs: String(localized: "PDFs")
        case .documents: String(localized: "Documents")
        case .videos: String(localized: "Videos")
        case .audio: String(localized: "Audio")
        case .archives: String(localized: "Archives")
        case .staleFiles: String(localized: "Untouched for 90 days")
        }
    }

    var tint: FileCategory {
        switch self {
        case .installedInstallers: .installers
        case .screenshots: .screenshots
        case .images: .images
        case .pdfs: .pdfs
        case .documents: .documents
        case .videos: .videos
        case .audio: .audio
        case .archives: .archives
        case .staleFiles: .other
        }
    }
}
