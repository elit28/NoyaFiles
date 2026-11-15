import NoyaCore
import SwiftUI

/// Folders side by side: selecting a folder opens it in the next column,
/// selecting a file shows its preview at the end.
struct ColumnBrowserView: View {
    @Bindable var model: BrowserModel

    /// The item selected in each column, from left to right.
    @State private var path: [FileItem] = []
    @FocusState private var focusedColumn: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.element) { index, folder in
                        FolderColumn(
                            folder: folder,
                            preloadedItems: index == 0 ? model.items : nil,
                            showHidden: model.showHidden,
                            selectedURL: index < path.count ? path[index].url : nil,
                            select: { item in select(item, inColumn: index) },
                            open: open,
                            quickLook: { item, siblings in model.quickLook(item.url, among: siblings) },
                            model: model
                        )
                        .frame(width: 250)
                        .focused($focusedColumn, equals: index)
                        .onKeyPress(.rightArrow) {
                            guard index + 1 < columns.count else { return .ignored }
                            focusedColumn = index + 1
                            return .handled
                        }
                        .onKeyPress(.leftArrow) {
                            guard index > 0 else { return .ignored }
                            path = Array(path.prefix(index))
                            focusedColumn = index - 1
                            return .handled
                        }
                        .id(index)
                        Divider()
                    }
                    if let file = selectedFile {
                        FileInfoPanel(item: file, model: model)
                            .frame(width: 330)
                            .id("preview")
                    }
                }
            }
            .onChange(of: path) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if selectedFile != nil {
                        proxy.scrollTo("preview", anchor: .trailing)
                    } else {
                        proxy.scrollTo(columns.count - 1, anchor: .trailing)
                    }
                }
            }
        }
        .onChange(of: model.location) {
            path = []
        }
    }

    /// The current folder, then each selected subfolder.
    private var columns: [URL] {
        [model.location.url] + path.prefix { $0.isFolder }.map(\.url)
    }

    /// The selected file or package, when the deepest selection is not a folder.
    private var selectedFile: FileItem? {
        guard let last = path.last, !last.isFolder, path.count == columns.count else { return nil }
        return last
    }

    private func select(_ item: FileItem?, inColumn index: Int) {
        var newPath = Array(path.prefix(index))
        if let item { newPath.append(item) }
        path = newPath
    }

    private func open(_ item: FileItem) {
        if item.isFolder {
            model.navigate(to: item.url)
        } else {
            model.open(urls: [item.url])
        }
    }
}

/// One folder's contents in the column browser.
private struct FolderColumn: View {
    let folder: URL
    /// The contents, when the caller already has them; otherwise the column reads the folder itself.
    let preloadedItems: [FileItem]?
    let showHidden: Bool
    let selectedURL: URL?
    let select: (FileItem?) -> Void
    let open: (FileItem) -> Void
    let quickLook: (FileItem, [URL]) -> Void
    let model: BrowserModel

    @State private var loadedItems: [FileItem] = []
    @State private var failure: BrowserError?

    var body: some View {
        Group {
            if let failure {
                ContentUnavailableView(failure.title, systemImage: failure.symbolName)
                    .controlSize(.small)
            } else {
                List(selection: selection) {
                    ForEach(items) { item in
                        row(for: item)
                            .tag(item.url)
                    }
                }
                .listStyle(.inset)
                .contextMenu(forSelectionType: URL.self) { urls in
                    ColumnContextMenu(urls: urls, model: model)
                } primaryAction: { urls in
                    if let url = urls.first, let item = items.first(where: { $0.url == url }) {
                        open(item)
                    }
                }
                .onKeyPress(.space) {
                    guard let url = selectedURL, let item = items.first(where: { $0.url == url }), !item.isFolder else {
                        return .ignored
                    }
                    quickLook(item, items.filter { !$0.isFolder }.map(\.url))
                    return .handled
                }
            }
        }
        .task(id: folder) {
            guard preloadedItems == nil else { return }
            failure = nil
            do {
                loadedItems = try await Self.read(folder)
            } catch {
                failure = BrowserError(error)
            }
        }
    }

    private var items: [FileItem] {
        (preloadedItems ?? loadedItems)
            .filter { showHidden || !$0.isHidden }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selection: Binding<URL?> {
        Binding(
            get: { selectedURL },
            set: { url in select(url.flatMap { url in items.first { $0.url == url } }) }
        )
    }

    private func row(for item: FileItem) -> some View {
        HStack(spacing: 7) {
            Image(nsImage: IconCache.icon(for: item))
                .resizable()
                .interpolation(.high)
                .frame(width: 17, height: 17)
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if item.isFolder {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .opacity(item.isHidden ? 0.55 : 1)
    }

    nonisolated private static func read(_ folder: URL) async throws -> [FileItem] {
        try DirectoryReader().items(in: folder)
    }
}

private struct ColumnContextMenu: View {
    let urls: Set<URL>
    let model: BrowserModel

    var body: some View {
        if !urls.isEmpty {
            let list = Array(urls)
            Button("Open") { model.open(urls: list) }
            Button("Quick Look") { model.quickLook(list[0], among: list) }
            Divider()
            Button("Show in Finder") { model.revealInFinder(urls: list) }
            Button("Copy Path") { model.copyPaths(urls: list) }
            AddToWorkspaceMenu(urls: list)
            Divider()
            Button("Move to Trash", role: .destructive) { model.moveToTrash(urls: list) }
        }
    }
}
