import NoyaCore
import QuickLook
import SwiftUI

/// A folder in the main area, with its toolbar, filter field and side panel.
struct BrowserScreen: View {
    @Bindable var model: BrowserModel
    let window: WindowModel

    var body: some View {
        BrowserView(model: model)
            .dropDestination(for: URL.self) { urls, _ in
                window.drop(urls, into: model.location.url)
                return true
            }
            .inspector(isPresented: $model.isInsightsVisible) {
                InspectorPanel(model: model)
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
            }
            .navigationTitle(model.title)
            .toolbar {
                BrowserToolbar(model: model, window: window)
            }
            .searchable(text: $model.searchText, placement: .toolbar, prompt: Text("Filter this folder"))
            .sheet(isPresented: $model.isGoToFolderPresented) {
                GoToFolderSheet(model: model)
            }
            .sheet(isPresented: $model.isDuplicatesSheetPresented) {
                DuplicatesSheet(model: model)
            }
            .quickLookPreview($model.quickLookURL, in: model.quickLookList)
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
        if let item = model.singleSelectedItem, model.viewMode != .columns {
            FileInfoPanel(item: item, model: model)
        } else if case .category(let category) = model.location.scope {
            CategoryInsightsPanel(model: model, category: category)
        } else {
            InsightsPanel(model: model)
        }
    }
}
