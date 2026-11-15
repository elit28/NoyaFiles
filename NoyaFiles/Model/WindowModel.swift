import Foundation
import Observation

/// What the main area of a window shows.
enum Destination: Hashable {
    case browser
}

/// What a sidebar row leads to.
enum SidebarSelection: Hashable {
    case folder(URL)
}

/// The state of one window: its browser and what the main area shows.
@MainActor
@Observable
final class WindowModel {
    let browser = BrowserModel()
    var destination: Destination = .browser

    /// The sidebar row matching what the window shows.
    var sidebarSelection: SidebarSelection? {
        get {
            switch destination {
            case .browser: .folder(browser.location.url)
            }
        }
        set {
            switch newValue {
            case .folder(let url)?:
                destination = .browser
                browser.navigate(to: url)
            case nil:
                break
            }
        }
    }
}
