import Foundation
import NoyaCore
import Observation
import PDFKit

/// Where a search looks.
enum SearchScope: Hashable {
    case thisMac
    case folder(URL)
    case workspace(UUID)
}

struct SearchResult: Identifiable, Hashable {
    let item: FileItem
    /// A short excerpt around the match, for files that matched by their contents.
    var snippet: String?

    var id: URL { item.url }
    var url: URL { item.url }
    var folder: URL { item.url.deletingLastPathComponent() }
}

/// Search results in one folder.
struct SearchResultGroup: Identifiable {
    let folder: URL
    let results: [SearchResult]

    var id: URL { folder }
}

/// A search the user saved, listed in the sidebar.
struct SavedSearch: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var criteria: SearchCriteria
}

/// Saved searches, kept in the app's preferences and shared by all windows.
@MainActor
@Observable
final class SavedSearchStore {
    static let shared = SavedSearchStore()
    private static let key = "search.saved"

    private(set) var searches: [SavedSearch] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([SavedSearch].self, from: data) {
            searches = decoded
        }
    }

    func search(_ id: UUID) -> SavedSearch? {
        searches.first { $0.id == id }
    }

    @discardableResult
    func save(name: String, criteria: SearchCriteria) -> UUID {
        let search = SavedSearch(name: name, criteria: criteria)
        searches.append(search)
        persist()
        return search.id
    }

    func delete(_ id: UUID) {
        searches.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(searches), forKey: Self.key)
    }
}

/// A Spotlight search of names and contents, with filters, run as the user types.
@MainActor
@Observable
final class SearchModel {
    var criteria = SearchCriteria() {
        didSet {
            if criteria != oldValue { scheduleSearch() }
        }
    }

    var scope: SearchScope = .thisMac {
        didSet {
            if scope != oldValue { scheduleSearch() }
        }
    }

    private(set) var results: [SearchResult] = []
    private(set) var isSearching = false
    private(set) var elapsed: TimeInterval?
    var selection: Set<URL> = []
    var quickLookURL: URL?
    /// The folder the window was showing, offered as a scope.
    var currentFolder: URL

    @ObservationIgnored private var query: NSMetadataQuery?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var snippetTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var workspaceURLs: [URL] = []

    private static let maxResults = 500

    init(currentFolder: URL) {
        self.currentFolder = currentFolder
    }

    /// Restricts a workspace search to the files and folders it gathers.
    func setWorkspaceURLs(_ urls: [URL]) {
        workspaceURLs = urls
    }

    var resultsByFolder: [SearchResultGroup] {
        var order: [URL] = []
        var groups: [URL: [SearchResult]] = [:]
        for result in results {
            if groups[result.folder] == nil { order.append(result.folder) }
            groups[result.folder, default: []].append(result)
        }
        return order.map { SearchResultGroup(folder: $0, results: groups[$0] ?? []) }
    }

    // MARK: - Running the query

    func scheduleSearch() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.start()
        }
    }

    func start() {
        stop()
        guard
            let queryString = criteria.spotlightQuery,
            let predicate = NSPredicate(fromMetadataQueryString: queryString)
        else {
            results = []
            isSearching = false
            elapsed = nil
            return
        }

        let query = NSMetadataQuery()
        query.predicate = predicate
        query.searchScopes = searchScopes
        query.notificationBatchingInterval = 0.3

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.collect(isFinal: true) }
            },
            center.addObserver(forName: .NSMetadataQueryGatheringProgress, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.collect(isFinal: false) }
            },
            center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.collect(isFinal: false) }
            },
        ]

        startedAt = Date()
        isSearching = true
        self.query = query
        query.start()
    }

    func stop() {
        query?.stop()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        query = nil
        snippetTask?.cancel()
    }

    private var searchScopes: [Any] {
        switch scope {
        case .thisMac:
            return [NSMetadataQueryLocalComputerScope]
        case .folder(let url):
            return [url]
        case .workspace:
            let folders = Set(workspaceURLs.map { url -> URL in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true ? url : url.deletingLastPathComponent()
            })
            return folders.isEmpty ? [URL(fileURLWithPath: "/nonexistent-noya-scope")] : Array(folders)
        }
    }

    private func belongsToScope(_ url: URL) -> Bool {
        guard case .workspace = scope else { return true }
        return workspaceURLs.contains { entry in
            url == entry || url.path.hasPrefix(entry.path + "/")
        }
    }

    private func collect(isFinal: Bool) {
        guard let query else { return }
        query.disableUpdates()
        var found: [SearchResult] = []
        let previousSnippets = Dictionary(results.compactMap { result in result.snippet.map { (result.url, $0) } }, uniquingKeysWith: { first, _ in first })
        for index in 0..<min(query.resultCount, Self.maxResults) {
            guard
                let item = query.result(at: index) as? NSMetadataItem,
                let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else { continue }
            let url = URL(fileURLWithPath: path)
            guard belongsToScope(url) else { continue }
            found.append(SearchResult(item: FileItem(contentsOf: url), snippet: previousSnippets[url]))
        }
        query.enableUpdates()
        results = found

        if isFinal {
            isSearching = false
            elapsed = Date().timeIntervalSince(startedAt)
            loadSnippets()
        }
    }

    // MARK: - Snippets

    private func loadSnippets() {
        snippetTask?.cancel()
        guard criteria.searchesContents,
              let word = criteria.text.split(whereSeparator: \.isWhitespace).first.map(String.init)
        else { return }
        let targets = results.prefix(40)
            .filter { $0.snippet == nil && !$0.item.name.localizedStandardContains(word) }
            .map(\.url)
        guard !targets.isEmpty else { return }

        snippetTask = Task { [weak self] in
            for url in targets {
                if Task.isCancelled { return }
                guard let snippet = await Self.snippet(for: url, word: word) else { continue }
                guard let self, let index = self.results.firstIndex(where: { $0.url == url }) else { continue }
                self.results[index].snippet = snippet
            }
        }
    }

    nonisolated private static func snippet(for url: URL, word: String) async -> String? {
        let fileExtension = url.pathExtension.lowercased()
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        if fileExtension == "pdf" {
            guard let document = PDFDocument(url: url) else { return nil }
            for index in 0..<min(document.pageCount, 50) {
                if let text = document.page(at: index)?.string,
                   let snippet = SnippetMaker.snippet(around: word, in: text) {
                    return snippet
                }
            }
            return nil
        }
        let textExtensions: Set<String> = ["txt", "md", "markdown", "csv", "tsv", "json", "xml", "yml", "yaml", "swift", "py", "js", "ts", "html", "css", "log"]
        guard textExtensions.contains(fileExtension), size < 4_000_000,
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return SnippetMaker.snippet(around: word, in: text)
    }
}
