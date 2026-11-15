import Foundation
import Observation

/// What the main area of a window shows.
enum Destination: Hashable {
    case browser
    case workspace(UUID)
}

/// What a sidebar row leads to.
enum SidebarSelection: Hashable {
    case folder(URL)
    case workspace(UUID)
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
    var destination: Destination = .browser
    var activePane: Pane = .primary

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
            }
        }
        set {
            switch newValue {
            case .folder(let url)?:
                destination = .browser
                activeBrowser.navigate(to: url)
            case .workspace(let id)?:
                destination = .workspace(id)
            case nil:
                break
            }
        }
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
