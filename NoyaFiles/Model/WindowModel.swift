import Foundation
import Observation

/// A tool with its own screen in the main area.
enum Tool: String, Hashable, CaseIterable {
    case freeUpSpace
    case developer
    case assistant
}

/// What the main area of a window shows.
enum Destination: Hashable {
    case browser
    case workspace(UUID)
    case search
    case tool(Tool)
}

/// What a sidebar row leads to.
enum SidebarSelection: Hashable {
    case folder(URL)
    case workspace(UUID)
    case search
    case savedSearch(UUID)
    case tool(Tool)
    /// A Git repository, shown in the developer tools.
    case repository(URL)
}

enum Pane: Hashable {
    case primary
    case secondary
}

/// The state of one window: its browsers and what the main area shows.
@MainActor
@Observable
final class WindowModel {
    let browser = BrowserModel()
    let operations = FileOperationCenter()
    private(set) var secondary: BrowserModel?
    private(set) var search: SearchModel?
    /// The saved search shown, if the search came from the sidebar.
    private(set) var savedSearchID: UUID?
    var destination: Destination = .browser
    var activePane: Pane = .primary
    var isTidyPresented = false

    var isDualPane = false {
        didSet {
            guard isDualPane != oldValue else { return }
            UserDefaults.standard.set(isDualPane, forKey: PreferenceKey.dualPane)
            if isDualPane {
                if secondary == nil {
                    secondary = BrowserModel(startingAt: .documentsDirectory, persistsLocation: false)
                }
                destination = .browser
            } else {
                activePane = .primary
                isComparing = false
            }
        }
    }

    /// Highlights the items that exist in only one of the two panes.
    var isComparing = false {
        didSet { updateComparison() }
    }

    init() {
        if UserDefaults.standard.bool(forKey: PreferenceKey.dualPane) {
            isDualPane = true
            secondary = BrowserModel(startingAt: .documentsDirectory, persistsLocation: false)
        }
        // A launch argument used by the automated screenshots, such as `-noya.startDestination search`.
        switch UserDefaults.standard.string(forKey: "noya.startDestination") {
        case "freeUpSpace": destination = .tool(.freeUpSpace)
        case "developer": destination = .tool(.developer)
        case "assistant": destination = .tool(.assistant)
        case "search": openSearch()
        default: break
        }
        isTidyPresented = UserDefaults.standard.bool(forKey: "noya.showTidy")
    }

    /// The browser that menu commands and the sidebar act on.
    var activeBrowser: BrowserModel {
        if isDualPane, activePane == .secondary, let secondary { return secondary }
        return browser
    }

    /// The other pane, when two are shown.
    var inactiveBrowser: BrowserModel? {
        guard isDualPane, let secondary else { return nil }
        return activePane == .primary ? secondary : browser
    }

    /// The sidebar row matching what the window shows.
    var sidebarSelection: SidebarSelection? {
        get {
            switch destination {
            case .browser: .folder(activeBrowser.location.url)
            case .workspace(let id): .workspace(id)
            case .search: savedSearchID.map { .savedSearch($0) } ?? .search
            case .tool(.developer):
                // The selected repository when the sidebar lists repositories, the tool otherwise.
                Self.sidebarListsRepositories
                    ? DeveloperModel.shared.selectedProject.flatMap { $0.isRepository ? .repository($0.url) : nil } ?? .tool(.developer)
                    : .tool(.developer)
            case .tool(let tool): .tool(tool)
            }
        }
        set {
            switch newValue {
            case .folder(let url)?:
                destination = .browser
                activeBrowser.navigate(to: url)
            case .workspace(let id)?:
                destination = .workspace(id)
            case .search?:
                openSearch()
            case .savedSearch(let id)?:
                openSearch(saved: SavedSearchStore.shared.search(id))
            case .tool(let tool)?:
                destination = .tool(tool)
            case .repository(let url)?:
                DeveloperModel.shared.selection = url
                destination = .tool(.developer)
            case nil:
                break
            }
        }
    }

    private static var sidebarListsRepositories: Bool {
        let stored = UserDefaults.standard.string(forKey: PreferenceKey.sidebarVisibility)
        let visibility = stored.flatMap(SidebarVisibility.init(rawValue:)) ?? .standard
        return visibility.shows("developer") && visibility.shows("repositories")
    }

    // MARK: - Search

    /// Shows the advanced search, optionally filled in from a saved search.
    func openSearch(saved: SavedSearch? = nil) {
        let model = search ?? SearchModel(currentFolder: activeBrowser.location.url)
        if destination != .search {
            model.currentFolder = activeBrowser.location.url
        }
        if let saved {
            model.criteria = saved.criteria
            savedSearchID = saved.id
        } else {
            savedSearchID = nil
        }
        search = model
        destination = .search
    }

    // MARK: - Dual pane

    func toggleActivePane() {
        guard isDualPane else { return }
        activePane = activePane == .primary ? .secondary : .primary
    }

    func swapPanes() {
        guard let secondary else { return }
        let left = browser.location.url
        browser.navigate(to: secondary.location.url)
        secondary.navigate(to: left)
    }

    /// Copies or moves the active pane's selection into the other pane's folder.
    func transferSelection(_ kind: TransferKind) {
        guard let target = inactiveBrowser else { return }
        let urls = activeBrowser.selectedItems.map(\.url)
        operations.transfer(kind, urls, to: target.location.url)
    }

    func updateComparison() {
        guard isComparing, let secondary else {
            browser.comparisonNames = nil
            secondary?.comparisonNames = nil
            return
        }
        let left = Set(browser.items.filter { !$0.isHidden }.map(\.name))
        let right = Set(secondary.items.filter { !$0.isHidden }.map(\.name))
        browser.comparisonNames = left.subtracting(right)
        secondary.comparisonNames = right.subtracting(left)
    }

    // MARK: - Drag and drop

    /// Files dropped on a folder are moved within the same disk and copied across disks, as in the Finder.
    func drop(_ urls: [URL], into folder: URL) {
        let targetVolume = Self.volumeIdentifier(of: folder)
        let sameVolume = !urls.isEmpty && urls.allSatisfy { Self.volumeIdentifier(of: $0) == targetVolume && targetVolume != nil }
        operations.transfer(sameVolume ? .move : .copy, urls, to: folder)
    }

    private static func volumeIdentifier(of url: URL) -> String? {
        let values = try? url.resourceValues(forKeys: [.volumeIdentifierKey])
        return values?.volumeIdentifier.map { "\($0)" }
    }
}
