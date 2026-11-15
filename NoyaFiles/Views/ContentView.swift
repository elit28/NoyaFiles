import SwiftUI

/// One browser window: sidebar, folder contents and the insights panel.
struct ContentView: View {
    @State private var model = BrowserModel()
    @State private var sidebar = SidebarModel()
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system

    var body: some View {
        NavigationSplitView {
            SidebarView(sidebar: sidebar, selection: sidebarSelection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            BrowserView(model: model)
                .inspector(isPresented: $model.isInsightsVisible) {
                    InsightsPanel(model: model)
                        .inspectorColumnWidth(min: 250, ideal: 290, max: 400)
                }
        }
        .navigationTitle(model.title)
        .toolbar {
            BrowserToolbar(model: model)
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: Text("Filter this folder"))
        .focusedSceneValue(\.browserModel, model)
        .sheet(isPresented: $model.isGoToFolderPresented) {
            GoToFolderSheet(model: model)
        }
        .alert(
            "Something went wrong",
            isPresented: isShowingError,
            presenting: model.errorMessage
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
        .frame(minWidth: 860, minHeight: 520)
        .preferredColorScheme(appearance.colorScheme)
    }

    /// The sidebar highlights the current folder when it is one of its places.
    private var sidebarSelection: Binding<URL?> {
        Binding(
            get: { model.location.url },
            set: { url in
                if let url { model.navigate(to: url) }
            }
        )
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if !isPresented { model.errorMessage = nil }
            }
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 740)
}
