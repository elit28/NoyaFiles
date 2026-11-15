import SwiftUI

/// One window: the sidebar and whatever the main area shows.
struct ContentView: View {
    @State private var window = WindowModel()
    @State private var sidebar = SidebarModel()
    @AppStorage(PreferenceKey.appearance) private var appearance = AppearancePreference.system
    @AppStorage(PreferenceKey.accent) private var accent = AccentPreference.teal
    private let workspaces = WorkspaceStore.shared

    var body: some View {
        NavigationSplitView {
            SidebarView(sidebar: sidebar, selection: $window.sidebarSelection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            switch window.destination {
            case .browser:
                if window.isDualPane {
                    DualPaneScreen(window: window)
                } else {
                    BrowserScreen(model: window.browser, window: window)
                }
            case .workspace(let id):
                WorkspaceScreen(workspaceID: id)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let operation = window.operations.current {
                OperationToast(operation: operation) {
                    window.operations.cancel()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: window.operations.current?.id)
        .alert("Something went wrong", isPresented: errorBinding, presenting: currentError) { _ in
            Button("OK") {
                window.operations.lastError = nil
                workspaces.lastError = nil
            }
        } message: { message in
            Text(message)
        }
        .environment(workspaces)
        .focusedSceneValue(\.browserModel, window.activeBrowser)
        .focusedSceneValue(\.windowModel, window)
        .tint(accent.color)
        .frame(minWidth: 900, minHeight: 540)
        .onChange(of: appearance, initial: true) {
            appearance.apply()
        }
    }

    private var currentError: String? {
        window.operations.lastError ?? workspaces.lastError
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { currentError != nil },
            set: { isPresented in
                if !isPresented {
                    window.operations.lastError = nil
                    workspaces.lastError = nil
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 740)
}
