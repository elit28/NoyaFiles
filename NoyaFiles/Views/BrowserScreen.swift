import NoyaCore
import SwiftUI

/// A folder in the main area, with its toolbar, filter field and side panel.
struct BrowserScreen: View {
    @Bindable var model: BrowserModel

    var body: some View {
        BrowserView(model: model)
            .inspector(isPresented: $model.isInsightsVisible) {
                InspectorPanel(model: model)
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
            }
            .navigationTitle(model.title)
            .toolbar {
                BrowserToolbar(model: model)
            }
            .searchable(text: $model.searchText, placement: .toolbar, prompt: Text("Filter this folder"))
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
            .confirmationDialog(
                model.pendingTrash?.title ?? "",
                isPresented: isConfirmingTrash,
                titleVisibility: .visible,
                presenting: model.pendingTrash
            ) { pending in
                Button("Move to Trash", role: .destructive) {
                    model.moveToTrash(urls: pending.urls)
                }
                Button("Cancel", role: .cancel) {}
            } message: { pending in
                Text(pending.message)
            }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if !isPresented { model.errorMessage = nil }
            }
        )
    }

    private var isConfirmingTrash: Binding<Bool> {
        Binding(
            get: { model.pendingTrash != nil },
            set: { isPresented in
                if !isPresented { model.pendingTrash = nil }
            }
        )
    }
}

/// The right-hand panel: details of the selected item, or insights about the folder.
struct InspectorPanel: View {
    let model: BrowserModel

    var body: some View {
        if let item = model.singleSelectedItem {
            FileInfoPanel(item: item, model: model)
        } else {
            InsightsPanel(model: model)
        }
    }
}
