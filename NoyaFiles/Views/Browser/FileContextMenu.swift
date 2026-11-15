import SwiftUI

/// The right-click menu for items, or for the folder itself when nothing is clicked.
struct FileContextMenu: View {
    let model: BrowserModel
    let ids: Set<BrowserNode.ID>

    var body: some View {
        if ids.isEmpty {
            Button("Show in Finder") { model.revealInFinder([]) }
            Button("Refresh") { model.reload() }
        } else {
            Button("Open") { model.open(ids) }
            if !model.items(for: ids).isEmpty {
                Button("Quick Look") {
                    model.selection = ids
                    model.toggleQuickLook()
                }
                Button("Show in Finder") { model.revealInFinder(ids) }
                Button("Copy Path") { model.copyPaths(ids) }
                AddToWorkspaceMenu(urls: model.items(for: ids).map(\.url))
                Divider()
                Button("Move to Trash", role: .destructive) { model.moveToTrash(ids) }
            }
        }
    }
}
