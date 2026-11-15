import SwiftUI

@main
struct NoyaFilesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1180, height: 740)
        .commands {
            BrowserCommands()
        }
    }
}

extension FocusedValues {
    /// The browser of the window that has keyboard focus, so menu commands can act on it.
    @Entry var browserModel: BrowserModel?
}
