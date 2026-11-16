import AppKit
import SwiftUI

/// The middle of the window: path bar, folder contents and status bar.
struct BrowserView: View {
    @Bindable var model: BrowserModel

    var body: some View {
        VStack(spacing: 0) {
            PathBar(model: model)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            StatusBar(model: model)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .failed(let error):
            FolderErrorView(error: error) {
                model.reload()
            }
        case .loaded:
            if model.rootNodes.isEmpty {
                emptyState
            } else {
                switch model.viewMode {
                case .list:
                    FileListView(model: model)
                case .grid:
                    FileGridView(model: model)
                case .columns:
                    ColumnBrowserView(model: model)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !model.searchText.isEmpty {
            ContentUnavailableView.search(text: model.searchText)
        } else if model.location.scope != .everything {
            ContentUnavailableView(
                "Nothing to show",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No items match this filter.")
            )
        } else {
            ContentUnavailableView {
                Label("This folder is empty", systemImage: "folder")
            } description: {
                Text("Drag files here, or create a folder with ⇧⌘N.")
            } actions: {
                Button("New Folder…") { model.isNewFolderPresented = true }
            }
        }
    }
}

struct FolderErrorView: View {
    let error: BrowserError
    let retry: () -> Void

    private static let privacySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: error.symbolName)
        } description: {
            Text(error.message)
        } actions: {
            if error == .permissionDenied {
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(Self.privacySettingsURL)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Try Again", action: retry)
        }
    }
}
