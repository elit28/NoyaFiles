import AppKit
import NoyaCore
import Observation

/// Items waiting for the user to confirm they go to the Trash.
struct PendingTrash: Identifiable {
    let id = UUID()
    let urls: [URL]
    let title: String
    let message: String
}

/// Everything one browser shows: where it is, what is inside, and how it is presented.
@MainActor
@Observable
final class BrowserModel {
    // MARK: - Location and history

    private(set) var location: BrowserLocation
    private var backStack: [BrowserLocation] = []
    private var forwardStack: [BrowserLocation] = []

    // MARK: - Folder contents

    private(set) var items: [FileItem] = []
    private(set) var measurements: [URL: FolderSizer.Measurement] = [:]
    private(set) var loadState: LoadState = .loading
    private(set) var availableCapacity: Int64?
    private(set) var pendingMeasurementCount = 0

    // MARK: - What the views display

    private(set) var rootNodes: [BrowserNode] = []
    private(set) var gridSections: [GridSection] = []
    private(set) var insights = FolderInsights(items: [], measurements: [:], includeHidden: false)
    private(set) var suggestions: [CleanupSuggestion] = []
    private(set) var visibleItemCount = 0

    // MARK: - Presentation options

    var viewMode: ViewMode {
        didSet { save(viewMode.rawValue, PreferenceKey.viewMode, changed: viewMode != oldValue) }
    }

    var grouping: GroupingMode {
        didSet {
            save(grouping.rawValue, PreferenceKey.grouping, changed: grouping != oldValue)
            rebuild()
        }
    }

    var sortOrder: [KeyPathComparator<BrowserNode>] = [SortField.dateAdded.comparator(order: .reverse)] {
        didSet { rebuild() }
    }

    var showHidden: Bool {
        didSet {
            guard showHidden != oldValue else { return }
            save(showHidden, PreferenceKey.showHidden, changed: true)
            rebuild()
            if showHidden { measureMissingContainers() }
        }
    }

    var isInsightsVisible: Bool {
        didSet { save(isInsightsVisible, PreferenceKey.insightsVisible, changed: isInsightsVisible != oldValue) }
    }

    var searchText = "" {
        didSet {
            if searchText != oldValue { rebuild() }
        }
    }

    private(set) var measuresFolders: Bool
    private(set) var keepsFoldersFirst: Bool

    var selection: Set<BrowserNode.ID> = []
    var dismissedSuggestions: Set<CleanupSuggestion.Kind> = []
    var isGoToFolderPresented = false
    var errorMessage: String?
    var pendingTrash: PendingTrash?

    // MARK: - Private state

    private let defaults: UserDefaults
    @ObservationIgnored private var nodesByID: [BrowserNode.ID: BrowserNode] = [:]
    @ObservationIgnored private var measuredStamps: [URL: Date] = [:]
    @ObservationIgnored private var installedAppNames: [String] = []
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var measureTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var watcher: DirectoryWatcher?
    @ObservationIgnored private var defaultsObserver: (any NSObjectProtocol)?

    private static let maxConcurrentMeasurements = 4

    init(defaults: UserDefaults = .standard, startingAt startURL: URL? = nil) {
        self.defaults = defaults
        viewMode = defaults.string(forKey: PreferenceKey.viewMode).flatMap(ViewMode.init(rawValue:)) ?? .grid
        grouping = defaults.string(forKey: PreferenceKey.grouping).flatMap(GroupingMode.init(rawValue:)) ?? .kind
        showHidden = defaults.bool(forKey: PreferenceKey.showHidden)
        isInsightsVisible = defaults.object(forKey: PreferenceKey.insightsVisible) as? Bool ?? true
        measuresFolders = defaults.object(forKey: PreferenceKey.measureFolders) as? Bool ?? true
        keepsFoldersFirst = defaults.object(forKey: PreferenceKey.foldersFirst) as? Bool ?? true
        location = BrowserLocation(url: (startURL ?? Self.initialFolder(defaults: defaults)).canonicalDirectory)

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncWithDefaults()
            }
        }
        load(remeasureAll: true)
    }

    // MARK: - Derived values

    var title: String {
        FileManager.default.displayName(atPath: location.url.path)
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { location.scope != .everything || location.url.path != "/" }
    var isMeasuring: Bool { pendingMeasurementCount > 0 }
    var isDownloadsFolder: Bool { location.url == URL.downloadsDirectory.canonicalDirectory }

    var selectedItems: [FileItem] { items(for: selection) }

    /// The selected item, when exactly one real item is selected.
    var singleSelectedItem: FileItem? {
        guard selection.count == 1 else { return nil }
        return selectedItems.first
    }

    var visibleSuggestions: [CleanupSuggestion] {
        suggestions.filter { !dismissedSuggestions.contains($0.kind) }
    }

    var sortField: SortField {
        get { sortOrder.first.flatMap { SortField(keyPath: $0.keyPath) } ?? .name }
        set { sortOrder = [newValue.comparator(order: sortDirection)] }
    }

    var sortDirection: SortOrder {
        get { sortOrder.first?.order ?? .forward }
        set { sortOrder = [sortField.comparator(order: newValue)] }
    }

    func items(for ids: Set<BrowserNode.ID>) -> [FileItem] {
        ids.compactMap { nodesByID[$0]?.item }
    }

    /// The items a context menu acts on: the whole selection when the clicked item is part of it.
    func contextTargets(for id: BrowserNode.ID) -> Set<BrowserNode.ID> {
        selection.contains(id) ? selection : [id]
    }

    // MARK: - Navigation

    func navigate(to url: URL) {
        go(to: BrowserLocation(url: url.canonicalDirectory))
    }

    func show(_ scope: BrowserScope) {
        go(to: BrowserLocation(url: location.url, scope: scope))
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(location)
        apply(previous)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(location)
        apply(next)
    }

    func goUp() {
        if location.scope != .everything {
            show(.everything)
        } else if location.url.path != "/" {
            navigate(to: location.url.deletingLastPathComponent())
        }
    }

    private func go(to destination: BrowserLocation) {
        guard destination != location else { return }
        backStack.append(location)
        forwardStack.removeAll()
        apply(destination)
    }

    private func apply(_ destination: BrowserLocation) {
        let folderChanged = destination.url != location.url
        location = destination
        selection = []
        searchText = ""

        if folderChanged {
            defaults.set(destination.url.path, forKey: PreferenceKey.lastPath)
            dismissedSuggestions = []
            items = []
            loadState = .loading
            load(remeasureAll: true)
        }
        rebuild()
    }

    // MARK: - Loading

    /// Reads the folder again and re-measures every subfolder.
    func reload() {
        load(remeasureAll: true)
    }

    private func load(remeasureAll: Bool) {
        loadTask?.cancel()
        measureTask?.cancel()
        pendingMeasurementCount = 0

        let url = location.url
        watch(url)

        loadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[FileItem], BrowserError> in
                do {
                    return .success(try DirectoryReader().items(in: url))
                } catch {
                    return .failure(BrowserError(error))
                }
            }.value
            let appNames = await Task.detached(priority: .utility) {
                InstalledAppMatcher.installedAppNames()
            }.value

            guard let self, !Task.isCancelled, self.location.url == url else { return }
            self.installedAppNames = appNames
            switch result {
            case .success(let items):
                self.items = items
                self.loadState = .loaded
                self.availableCapacity = Self.availableCapacity(at: url)
                self.rebuild()
                self.measureContainers(in: items, remeasureAll: remeasureAll)
            case .failure(let error):
                self.items = []
                self.loadState = .failed(error)
                self.rebuild()
            }
        }
    }

    /// Measures folders and packages in the background, a few at a time.
    private func measureContainers(in items: [FileItem], remeasureAll: Bool) {
        measureTask?.cancel()
        guard measuresFolders else {
            pendingMeasurementCount = 0
            return
        }
        let targets = items.filter { item in
            guard item.isContainer, showHidden || !item.isHidden else { return false }
            if remeasureAll || measurements[item.url] == nil { return true }
            return measuredStamps[item.url] != item.modificationDate
        }
        pendingMeasurementCount = targets.count
        guard !targets.isEmpty else { return }

        measureTask = Task { [weak self] in
            await withTaskGroup(of: (FileItem, FolderSizer.Measurement).self) { group in
                var queue = targets.makeIterator()
                for _ in 0..<Self.maxConcurrentMeasurements {
                    guard let next = queue.next() else { break }
                    group.addTask { (next, FolderSizer.measure(next.url)) }
                }

                while let result = await group.next() {
                    guard let self, !Task.isCancelled else {
                        group.cancelAll()
                        return
                    }
                    let (item, measurement) = result
                    self.measurements[item.url] = measurement
                    self.measuredStamps[item.url] = item.modificationDate
                    self.pendingMeasurementCount = max(0, self.pendingMeasurementCount - 1)
                    self.rebuild()

                    if let next = queue.next() {
                        group.addTask { (next, FolderSizer.measure(next.url)) }
                    }
                }
            }
        }
    }

    private func measureMissingContainers() {
        guard loadState == .loaded else { return }
        measureContainers(in: items, remeasureAll: false)
    }

    private func watch(_ url: URL) {
        guard watcher?.url != url else { return }
        watcher = DirectoryWatcher(url: url) { [weak self] in
            self?.scheduleRefresh()
        }
    }

    /// Coalesces bursts of file system events into a single refresh.
    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.load(remeasureAll: false)
        }
    }

    private static func availableCapacity(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    private static func initialFolder(defaults: UserDefaults) -> URL {
        let fileManager = FileManager.default
        let start = defaults.string(forKey: PreferenceKey.startLocation).flatMap(StartLocation.init(rawValue:)) ?? .last
        if let url = start.url {
            return url
        }
        if let path = defaults.string(forKey: PreferenceKey.lastPath) {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return url
            }
        }
        return URL.downloadsDirectory
    }

    // MARK: - Preferences

    private func save(_ value: Any, _ key: String, changed: Bool) {
        guard changed else { return }
        defaults.set(value, forKey: key)
    }

    /// Picks up changes made in the Settings window or in another window.
    private func syncWithDefaults() {
        let storedShowHidden = defaults.bool(forKey: PreferenceKey.showHidden)
        if storedShowHidden != showHidden { showHidden = storedShowHidden }

        let storedMeasures = defaults.object(forKey: PreferenceKey.measureFolders) as? Bool ?? true
        if storedMeasures != measuresFolders {
            measuresFolders = storedMeasures
            if storedMeasures { measureMissingContainers() } else { measureTask?.cancel(); pendingMeasurementCount = 0 }
        }

        let storedFoldersFirst = defaults.object(forKey: PreferenceKey.foldersFirst) as? Bool ?? true
        if storedFoldersFirst != keepsFoldersFirst {
            keepsFoldersFirst = storedFoldersFirst
            rebuild()
        }

        if let mode = defaults.string(forKey: PreferenceKey.viewMode).flatMap(ViewMode.init(rawValue:)), mode != viewMode {
            viewMode = mode
        }
        if let mode = defaults.string(forKey: PreferenceKey.grouping).flatMap(GroupingMode.init(rawValue:)), mode != grouping {
            grouping = mode
        }
    }

    // MARK: - Building what the views display

    private func rebuild() {
        let now = Date()
        let visible = showHidden ? items : items.filter { !$0.isHidden }

        insights = FolderInsights(items: items, measurements: measurements, includeHidden: showHidden)
        suggestions = CleanupAdvisor.suggestions(for: visible, now: now, installedAppNames: installedAppNames)

        var shown: [FileItem]
        switch location.scope {
        case .everything:
            shown = visible
        case .category(let category):
            shown = visible.filter { !$0.isFolder && $0.category == category }
        case .staleFiles(let days):
            shown = visible.filter { $0.kind == .file && $0.isStale(olderThan: days, now: now) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            shown = shown.filter { $0.name.localizedStandardContains(query) }
        }
        visibleItemCount = shown.count

        // Inside a category, grouping by kind would only produce a single group.
        let effectiveGrouping: GroupingMode =
            location.scope != .everything && grouping == .kind ? .flat : grouping

        rootNodes = NodeBuilder.build(
            items: shown,
            grouping: effectiveGrouping,
            measurements: measurements,
            sortOrder: sortOrder,
            foldersFirst: keepsFoldersFirst,
            now: now
        )
        gridSections = makeGridSections(for: effectiveGrouping)

        var index: [BrowserNode.ID: BrowserNode] = [:]
        func addToIndex(_ nodes: [BrowserNode]) {
            for node in nodes {
                index[node.id] = node
                if let children = node.children { addToIndex(children) }
            }
        }
        addToIndex(rootNodes)
        nodesByID = index

        let validSelection = selection.filter { index[$0] != nil }
        if validSelection != selection { selection = validSelection }
    }

    private func makeGridSections(for grouping: GroupingMode) -> [GridSection] {
        switch grouping {
        case .flat:
            return rootNodes.isEmpty ? [] : [GridSection(id: "all", title: nil, nodes: rootNodes)]
        case .kind:
            var sections: [GridSection] = []
            let folders = rootNodes.filter { !$0.isGroup }
            let groups = rootNodes.filter(\.isGroup)
            if !folders.isEmpty {
                sections.append(GridSection(id: "folders", title: String(localized: "Folders"), nodes: folders))
            }
            if !groups.isEmpty {
                sections.append(GridSection(id: "kinds", title: String(localized: "By Kind"), nodes: groups))
            }
            return sections
        case .date:
            return rootNodes.map { GridSection(id: $0.id, title: $0.name, nodes: $0.children ?? []) }
        }
    }

    // MARK: - Actions

    func select(_ id: BrowserNode.ID, toggling: Bool) {
        if toggling {
            if selection.contains(id) {
                selection.remove(id)
            } else {
                selection.insert(id)
            }
        } else {
            selection = [id]
        }
    }

    /// Opens folders and groups inside the browser, and files with their default app.
    func open(_ ids: Set<BrowserNode.ID>) {
        let nodes = ids.compactMap { nodesByID[$0] }
        if nodes.count == 1, let node = nodes.first {
            switch node.content {
            case .category(let category):
                show(.category(category))
                return
            case .dateBucket:
                return
            case .item(let item) where item.isFolder:
                navigate(to: item.url)
                return
            case .item:
                break
            }
        }
        for item in nodes.compactMap(\.item) where !item.isFolder {
            NSWorkspace.shared.open(item.url)
        }
    }

    func revealInFinder(_ ids: Set<BrowserNode.ID>) {
        let urls = items(for: ids).map(\.url)
        NSWorkspace.shared.activateFileViewerSelecting(urls.isEmpty ? [location.url] : urls)
    }

    func copyPaths(_ ids: Set<BrowserNode.ID>) {
        let paths = items(for: ids).map(\.url.path)
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    /// Moves the items behind some nodes to the Trash, where the user can still recover them.
    func moveToTrash(_ ids: Set<BrowserNode.ID>) {
        moveToTrash(urls: items(for: ids).map(\.url))
    }

    /// Moves files to the Trash, where the user can still recover them.
    func moveToTrash(urls: [URL]) {
        guard !urls.isEmpty else { return }
        var failures: [String] = []
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                failures.append(url.lastPathComponent)
            }
        }
        if !failures.isEmpty {
            let names = failures.joined(separator: ", ")
            errorMessage = String(localized: "These items could not be moved to the Trash: \(names)")
        }
        selection.subtract(urls.map(\.path))
        load(remeasureAll: false)
    }

    /// Asks for confirmation before trashing installers whose app is already installed.
    func requestTrashingInstalled(from suggestion: CleanupSuggestion) {
        let matches = suggestion.installedMatches
        guard !matches.isEmpty else { return }
        let bytes = matches.reduce(Int64(0)) { $0 + $1.bytes }
        let apps = matches.map(\.appName).formatted(.list(type: .and))
        pendingTrash = PendingTrash(
            urls: matches.map(\.installerURL),
            title: String(localized: "Move \(matches.count) installers to the Trash?"),
            message: String(localized: "Already installed: \(apps). This frees \(bytes.formattedByteCount).")
        )
    }

    func review(_ suggestion: CleanupSuggestion) {
        switch suggestion.kind {
        case .installers:
            show(.category(.installers))
        case .staleFiles(let days):
            show(.staleFiles(days: days))
        }
    }

    func dismiss(_ suggestion: CleanupSuggestion) {
        dismissedSuggestions.insert(suggestion.kind)
    }
}
