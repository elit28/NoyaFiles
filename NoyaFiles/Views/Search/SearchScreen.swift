import AppKit
import NoyaCore
import QuickLook
import SwiftUI

/// Searches the Mac by name and contents, with filters, and lists results by folder.
struct SearchScreen: View {
    @Bindable var search: SearchModel
    let window: WindowModel

    @Environment(WorkspaceStore.self) private var workspaces
    @FocusState private var isFieldFocused: Bool
    @State private var showsFilters = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            results
        }
        .navigationTitle("Search")
        .inspector(isPresented: $showsFilters) {
            SearchFiltersPanel(search: search)
                .inspectorColumnWidth(min: 240, ideal: 270, max: 360)
        }
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showsFilters) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .help("Show or hide filters")
            }
        }
        .quickLookPreview($search.quickLookURL, in: search.results.map(\.url))
        .onAppear {
            isFieldFocused = true
            search.scheduleSearch()
        }
        .onDisappear {
            search.stop()
        }
        .onChange(of: search.scope, initial: true) {
            if case .workspace(let id) = search.scope {
                search.setWorkspaceURLs(workspaces.workspace(id)?.entries.compactMap { $0.resolvedURL() } ?? [])
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search names and contents", text: $search.criteria.text)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFieldFocused)
                    .onSubmit { search.start() }
                if !search.criteria.text.isEmpty {
                    Button {
                        search.criteria.text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.tint, lineWidth: isFieldFocused ? 2 : 0)
            }

            HStack(spacing: 8) {
                Picker("Search in", selection: $search.scope) {
                    Text("This Mac").tag(SearchScope.thisMac)
                    Text(FileManager.default.displayName(atPath: search.currentFolder.path))
                        .tag(SearchScope.folder(search.currentFolder))
                    ForEach(workspaces.workspaces) { workspace in
                        Text(workspace.name).tag(SearchScope.workspace(workspace.id))
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                ActiveFilterChips(search: search)
            }
        }
        .padding(16)
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        if search.criteria.isEmpty {
            ContentUnavailableView(
                "Search your Mac",
                systemImage: "magnifyingglass",
                description: Text("Type a word to find it in file names and inside documents. Add filters on the right.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if search.results.isEmpty && !search.isSearching {
            ContentUnavailableView.search(text: search.criteria.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if search.isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                List(selection: $search.selection) {
                    ForEach(search.resultsByFolder) { group in
                        Section {
                            ForEach(group.results) { result in
                                SearchResultRow(result: result, words: words)
                                    .tag(result.url)
                            }
                        } header: {
                            Text(verbatim: "\(Self.folderTitle(group.folder)) · \(group.results.count)")
                        }
                    }
                }
                .contextMenu(forSelectionType: URL.self) { urls in
                    if !urls.isEmpty {
                        let list = Array(urls)
                        Button("Open") { open(list) }
                        Button("Quick Look") { search.quickLookURL = list[0] }
                        Button("Show in Folder") { showInBrowser(list[0]) }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(list) }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(list.map(\.path).joined(separator: "\n"), forType: .string)
                        }
                        AddToWorkspaceMenu(urls: list)
                    }
                } primaryAction: { urls in
                    open(Array(urls))
                }
                .onKeyPress(.space) {
                    guard let first = search.results.first(where: { search.selection.contains($0.url) }) else { return .ignored }
                    search.quickLookURL = search.quickLookURL == nil ? first.url : nil
                    return .handled
                }
            }
        }
    }

    private var words: [String] {
        search.criteria.text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private var summary: String {
        let count = search.results.count
        guard let elapsed = search.elapsed else { return String(localized: "\(count) results") }
        let seconds = elapsed.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "\(count) results in \(seconds) s")
    }

    private func open(_ urls: [URL]) {
        if urls.count == 1, let url = urls.first,
           (try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])).map({ $0.isDirectory == true && $0.isPackage != true }) == true {
            showInBrowser(url, insideFolder: true)
            return
        }
        urls.forEach { NSWorkspace.shared.open($0) }
    }

    /// Shows a result in the browser: the folder itself, or the folder that holds the file.
    private func showInBrowser(_ url: URL, insideFolder: Bool = false) {
        window.destination = .browser
        window.activeBrowser.navigate(to: insideFolder ? url : url.deletingLastPathComponent())
    }

    /// A folder as a short path, such as “Documents › Administratif”.
    static func folderTitle(_ folder: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var path = folder.path
        if path.hasPrefix(home) {
            path = String(path.dropFirst(home.count))
        }
        let parts = path.split(separator: "/").map(String.init)
        return parts.isEmpty ? FileManager.default.displayName(atPath: folder.path) : parts.joined(separator: " › ")
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let words: [String]

    var body: some View {
        HStack(spacing: 10) {
            FileThumbnail(item: result.item, side: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(highlighted(result.item.name))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let snippet = result.snippet {
                    Text(highlighted(snippet))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if !result.item.isFolder {
                    Text(result.item.size.formattedByteCount)
                }
                if let date = result.item.modificationDate {
                    Text(date, format: .dateTime.day().month(.abbreviated).year())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for word in words where !word.isEmpty {
            var searchStart = attributed.startIndex
            while searchStart < attributed.endIndex,
                  let range = attributed[searchStart...].range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
                attributed[range].inlinePresentationIntent = .stronglyEmphasized
                attributed[range].backgroundColor = Color.accentColor.opacity(0.25)
                searchStart = range.upperBound
            }
        }
        return attributed
    }
}

/// The filters in use, shown as chips that can be removed one by one.
private struct ActiveFilterChips: View {
    @Bindable var search: SearchModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(search.criteria.kinds.sorted { $0.rawValue < $1.rawValue }, id: \.self) { kind in
                    chip(label: String(localized: "Kind"), value: kind.title) {
                        search.criteria.kinds.remove(kind)
                    }
                }
                if search.criteria.period != .any {
                    chip(label: String(localized: "Date"), value: search.criteria.period.title) {
                        search.criteria.period = .any
                    }
                }
                if search.criteria.minimumSize > 0 {
                    chip(label: String(localized: "Size"), value: "> " + search.criteria.minimumSize.formattedByteCount) {
                        search.criteria.minimumSize = 0
                    }
                }
                ForEach(search.criteria.tags.sorted(), id: \.self) { tag in
                    chip(label: String(localized: "Tag"), value: tag) {
                        search.criteria.tags.remove(tag)
                    }
                }
                if !search.criteria.searchesContents {
                    chip(label: String(localized: "Names only"), value: nil) {
                        search.criteria.searchesContents = true
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    private func chip(label: String, value: String?, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(.secondary)
            if let value {
                Text(value)
                    .fontWeight(.semibold)
            }
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
            .help("Remove filter")
        }
        .font(.callout)
        .padding(.leading, 10)
        .padding(.trailing, 7)
        .padding(.vertical, 3)
        .background(.tint.opacity(0.15), in: Capsule())
    }
}

/// The filters on the right of the search.
private struct SearchFiltersPanel: View {
    @Bindable var search: SearchModel
    @Environment(SavedSearchStore.self) private var savedSearches
    @State private var newTag = ""
    @State private var isNaming = false
    @State private var newName = ""

    private let sizes: [Int64] = [0, 100_000, 1_000_000, 10_000_000, 100_000_000, 1_000_000_000]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Toggle("Search inside documents", isOn: $search.criteria.searchesContents)

                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("Kind")
                    ForEach(SearchCriteria.Kind.allCases, id: \.self) { kind in
                        Toggle(kind.title, isOn: Binding(
                            get: { search.criteria.kinds.contains(kind) },
                            set: { isOn in
                                if isOn {
                                    search.criteria.kinds.insert(kind)
                                } else {
                                    search.criteria.kinds.remove(kind)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("Modified")
                    Picker("Modified", selection: $search.criteria.period) {
                        ForEach(SearchCriteria.Period.allCases, id: \.self) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("Minimum size")
                    Picker("Minimum size", selection: $search.criteria.minimumSize) {
                        ForEach(sizes, id: \.self) { size in
                            Text(size == 0 ? String(localized: "Any size") : size.formattedByteCount).tag(size)
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("Tags")
                    FlowRow(spacing: 6) {
                        ForEach(search.criteria.tags.sorted(), id: \.self) { tag in
                            Text(tag)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.15), in: Capsule())
                        }
                    }
                    TextField("Add a tag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            let tag = newTag.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces))
                            newTag = ""
                            if !tag.isEmpty { search.criteria.tags.insert(tag) }
                        }
                }

                Button("Save Search…") { isNaming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(search.criteria.isEmpty)
                    .popover(isPresented: $isNaming, arrowEdge: .bottom) {
                        TextField("Name", text: $newName, prompt: Text(search.criteria.text.isEmpty ? String(localized: "My search") : search.criteria.text))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                            .padding()
                            .onSubmit {
                                let name = newName.trimmingCharacters(in: .whitespaces)
                                savedSearches.save(name: name.isEmpty ? search.criteria.text : name, criteria: search.criteria)
                                newName = ""
                                isNaming = false
                            }
                    }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

extension SearchCriteria.Kind {
    var title: String {
        switch self {
        case .folders: String(localized: "Folders")
        case .documents: String(localized: "Documents")
        case .pdfs: String(localized: "PDFs")
        case .images: String(localized: "Images")
        case .videos: String(localized: "Videos")
        case .audio: String(localized: "Audio")
        case .archives: String(localized: "Archives")
        case .installers: String(localized: "Installers")
        case .code: String(localized: "Code")
        case .mail: String(localized: "Mail")
        }
    }
}

extension SearchCriteria.Period {
    var title: String {
        switch self {
        case .any: String(localized: "Any Date")
        case .today: String(localized: "Today")
        case .week: String(localized: "This Week")
        case .month: String(localized: "This Month")
        case .year: String(localized: "This Year")
        }
    }
}
