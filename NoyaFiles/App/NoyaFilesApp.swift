import SwiftUI

@main
struct NoyaFilesApp: App {
    init() {
        // Remember the language the app started in, to tell when a change needs a relaunch.
        _ = AppLanguage.atLaunch
        // Starts Sparkle, which looks for new versions in the background when allowed to.
        _ = AppUpdater.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { AppUpdater.shared.checkForUpdates() }
            }
            BrowserCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

extension EnvironmentValues {
    /// Opens the Downloads tidy-up of the current window.
    @Entry var tidyUp: @MainActor () -> Void = {}
}

extension FocusedValues {
    /// The browser of the window that has keyboard focus, so menu commands can act on it.
    @Entry var browserModel: BrowserModel?

    /// The window that has keyboard focus, for dual-pane commands.
    @Entry var windowModel: WindowModel?
}
