import SwiftUI

/// One window: the sidebar and whatever the main area shows.
struct ContentView: View {
    @State private var window = WindowModel()
    @State private var sidebar = SidebarModel()
    @AppStorage(PreferenceKey.appearance) private var appearance = AppearancePreference.system
    @AppStorage(PreferenceKey.accent) private var accent = AccentPreference.teal

    var body: some View {
        NavigationSplitView {
            SidebarView(sidebar: sidebar, selection: $window.sidebarSelection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            switch window.destination {
            case .browser:
                BrowserScreen(model: window.browser)
            }
        }
        .focusedSceneValue(\.browserModel, window.browser)
        .tint(accent.color)
        .frame(minWidth: 900, minHeight: 540)
        .onChange(of: appearance, initial: true) {
            appearance.apply()
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 740)
}
