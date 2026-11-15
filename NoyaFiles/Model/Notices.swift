import Foundation
import Observation

/// A short message in the corner of the window, with an optional action such as Undo.
struct Notice: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let symbolName: String
    let actionTitle: String?
    let action: (@MainActor () -> Void)?

    static func == (lhs: Notice, rhs: Notice) -> Bool {
        lhs.id == rhs.id
    }
}

/// Shows one notice at a time and hides it after a few seconds.
@MainActor
@Observable
final class NoticeCenter {
    static let shared = NoticeCenter()

    private(set) var current: Notice?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(
        _ message: String,
        symbolName: String = "checkmark.circle",
        actionTitle: String? = nil,
        action: (@MainActor () -> Void)? = nil
    ) {
        let notice = Notice(message: message, symbolName: symbolName, actionTitle: actionTitle, action: action)
        current = notice
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(action == nil ? 4 : 8))
            guard !Task.isCancelled, self?.current?.id == notice.id else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        hideTask?.cancel()
        current = nil
    }

    /// Runs the notice's action, then hides it.
    func perform() {
        let action = current?.action
        dismiss()
        action?()
    }
}

/// Runs one Spotlight query and returns what it found, without keeping it live.
@MainActor
enum Spotlight {
    struct Hit: Sendable {
        let url: URL
        let size: Int64
        let lastUsed: Date?
    }

    /// Keeps the query and its observer alive until the search finishes.
    @MainActor
    private final class QueryBox {
        let query = NSMetadataQuery()
        var observer: (any NSObjectProtocol)?
    }

    static func find(_ queryString: String, in scopes: [Any], limit: Int = 300) async -> [Hit] {
        guard let predicate = NSPredicate(fromMetadataQueryString: queryString) else { return [] }
        let box = QueryBox()
        box.query.predicate = predicate
        box.query.searchScopes = scopes

        return await withCheckedContinuation { continuation in
            box.observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: box.query,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    let query = box.query
                    query.stop()
                    var hits: [Hit] = []
                    for index in 0..<min(query.resultCount, limit) {
                        guard
                            let item = query.result(at: index) as? NSMetadataItem,
                            let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
                        else { continue }
                        let size = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? 0
                        let lastUsed = item.value(forAttribute: "kMDItemLastUsedDate") as? Date
                        hits.append(Hit(url: URL(fileURLWithPath: path), size: size, lastUsed: lastUsed))
                    }
                    if let observer = box.observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    box.observer = nil
                    continuation.resume(returning: hits)
                }
            }
            if !box.query.start() {
                if let observer = box.observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: [])
            }
        }
    }
}
