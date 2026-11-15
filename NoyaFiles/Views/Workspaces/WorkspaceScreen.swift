import AppKit
import NoyaCore
import SwiftUI

/// One row of a workspace: the saved entry and what it points to today.
struct WorkspaceRow: Identifiable, Hashable {
    let entry: WorkspaceEntry
    let url: URL?
    let item: FileItem?
    let tags: [String]

    var id: UUID { entry.id }
    var name: String { item?.name ?? (entry.path as NSString).lastPathComponent }
    var isMissing: Bool { url == nil }
    var location: String {
        let folder = url?.deletingLastPathComponent() ?? URL(fileURLWithPath: entry.path).deletingLastPathComponent()
        return (folder.path as NSString).abbreviatingWithTildeInPath
    }
    var modificationDate: Date { item?.modificationDate ?? .distantPast }
}

/// A workspace: its collections, pinned files, every file it gathers, and its smart rules.
struct WorkspaceScreen: View {
    let workspaceID: UUID
    @Environment(WorkspaceStore.self) private var store

    @State private var rows: [WorkspaceRow] = []
    @State private var collectionFilter: UUID?
    @State private var showsAll = true
    @State private var selection: Set<UUID> = []
    @State private var isEditing = false
    @State private var isAddingRule = false
    @State private var isNamingCollection = false
    @State private var newCollectionName = ""
    @State private var showsRules = true

    var body: some View {
        if let workspace = store.workspace(workspaceID) {
            content(for: workspace)
                .task(id: workspace.entries) {
                    rows = await Self.resolve(workspace.entries)
                }
                .inspector(isPresented: $showsRules) {
                    RulesPanel(workspace: workspace, isAddingRule: $isAddingRule)
                        .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
                }
                .toolbar {
                    ToolbarItem {
                        Button {
                            addFiles(to: workspace)
                        } label: {
                            Label("Add Files", systemImage: "plus")
                        }
                        .help("Add files or folders to this workspace")
                    }
                    ToolbarItem {
                        Toggle(isOn: $showsRules) {
                            Label("Smart Rules", systemImage: "wand.and.stars")
                        }
                        .help("Show or hide smart rules")
                    }
                }
                .navigationTitle(workspace.name)
                .sheet(isPresented: $isEditing) {
                    WorkspaceEditorSheet(workspace: workspace)
                }
                .sheet(isPresented: $isAddingRule) {
                    RuleEditorSheet(workspace: workspace)
                }
        } else {
            ContentUnavailableView("This workspace no longer exists", systemImage: "square.dashed")
        }
    }

    private func content(for workspace: Workspace) -> some View {
        let shown = rows.filter { showsAll || $0.entry.collectionID == collectionFilter }
        let pinned = shown.filter(\.entry.isPinned)
        let folders = Set(rows.compactMap { $0.url?.deletingLastPathComponent().path }).count

        return VStack(alignment: .leading, spacing: 0) {
            header(for: workspace, folderCount: folders)
            Divider()
            collectionBar(for: workspace)
            Divider()
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("This workspace is empty", systemImage: "tray")
                } description: {
                    Text("Drop files here, use Add Files, or create a smart rule. Files stay where they are.")
                } actions: {
                    Button("Add Files…") { addFiles(to: workspace) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if !pinned.isEmpty {
                            PinnedSection(rows: pinned, open: open)
                        }
                        EntriesTable(
                            rows: shown,
                            workspace: workspace,
                            selection: $selection,
                            open: open
                        )
                        .frame(minHeight: 320)
                        Text("A workspace gathers files without moving them: the originals stay where they are.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            store.add(urls, to: workspace.id, collection: showsAll ? nil : collectionFilter)
            return true
        }
    }

    private func header(for workspace: Workspace, folderCount: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(workspace.color.color.gradient)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.title2.weight(.bold))
                Text(subtitle(for: workspace, folderCount: folderCount))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit Workspace…") { isEditing = true }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func subtitle(for workspace: Workspace, folderCount: Int) -> String {
        let counts = String(localized: "\(workspace.entries.count) items from \(folderCount) folders")
        return workspace.summary.isEmpty ? counts : [workspace.summary, counts].joined(separator: " · ")
    }

    private func collectionBar(for workspace: Workspace) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                CollectionChip(title: String(localized: "All · \(workspace.entries.count)"), isSelected: showsAll) {
                    showsAll = true
                }
                ForEach(workspace.collections) { collection in
                    let count = workspace.entries.filter { $0.collectionID == collection.id }.count
                    CollectionChip(title: collection.name + " · \(count)", isSelected: !showsAll && collectionFilter == collection.id) {
                        showsAll = false
                        collectionFilter = collection.id
                    }
                    .contextMenu {
                        Button("Delete Collection", role: .destructive) {
                            if collectionFilter == collection.id { showsAll = true }
                            store.removeCollection(collection.id, from: workspace.id)
                        }
                    }
                }
                Button("New Collection…") { isNamingCollection = true }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $isNamingCollection, arrowEdge: .bottom) {
                        TextField("Collection name", text: $newCollectionName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                            .padding()
                            .onSubmit {
                                let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                                newCollectionName = ""
                                isNamingCollection = false
                                guard !name.isEmpty else { return }
                                collectionFilter = store.addCollection(named: name, to: workspace.id)
                                showsAll = false
                            }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.never)
    }

    private func open(_ row: WorkspaceRow) {
        guard let url = row.url else { return }
        NSWorkspace.shared.open(url)
    }

    private func addFiles(to workspace: Workspace) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = String(localized: "Add")
        guard panel.runModal() == .OK else { return }
        store.add(panel.urls, to: workspace.id, collection: showsAll ? nil : collectionFilter)
    }

    nonisolated private static func resolve(_ entries: [WorkspaceEntry]) async -> [WorkspaceRow] {
        entries.map { entry in
            guard let url = entry.resolvedURL() else {
                return WorkspaceRow(entry: entry, url: nil, item: nil, tags: [])
            }
            let tags = (try? url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? []
            return WorkspaceRow(entry: entry, url: url, item: FileItem(contentsOf: url), tags: tags)
        }
    }
}

private struct CollectionChip: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(title)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.primary))
                .background(
                    isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
                .overlay {
                    if !isSelected {
                        Capsule().strokeBorder(Color.primary.opacity(0.18))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PinnedSection: View {
    let rows: [WorkspaceRow]
    let open: (WorkspaceRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(rows) { row in
                    Button {
                        open(row)
                    } label: {
                        HStack(spacing: 10) {
                            if let item = row.item {
                                FileThumbnail(item: item, side: 40)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Text(row.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EntriesTable: View {
    let rows: [WorkspaceRow]
    let workspace: Workspace
    @Binding var selection: Set<UUID>
    let open: (WorkspaceRow) -> Void
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        Table(rows, selection: $selection) {
            TableColumn("Name") { row in
                HStack(spacing: 7) {
                    if let item = row.item {
                        Image(nsImage: IconCache.icon(for: item))
                            .resizable()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "questionmark.square.dashed")
                            .foregroundStyle(.secondary)
                    }
                    Text(row.name)
                        .lineLimit(1)
                    if row.entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                .opacity(row.isMissing ? 0.5 : 1)
                .help(row.isMissing ? String(localized: "This file can no longer be found.") : "")
            }
            .width(min: 180, ideal: 260)
            TableColumn("Collection") { row in
                Text(workspace.collection(row.entry.collectionID)?.name ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 130)
            TableColumn("Original Location") { row in
                Text(row.isMissing ? String(localized: "Not found") : row.location)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .width(min: 140, ideal: 220)
            TableColumn("Modified") { row in
                Text(DateText.string(for: row.modificationDate))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 140)
            TableColumn("Tags") { row in
                Text(row.tags.joined(separator: ", "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 120)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if !ids.isEmpty {
                let chosen = rows.filter { ids.contains($0.id) }
                Button("Open") { chosen.forEach(open) }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(chosen.compactMap(\.url))
                }
                Divider()
                if chosen.contains(where: { !$0.entry.isPinned }) {
                    Button("Pin") { store.setPinned(true, ids, in: workspace.id) }
                } else {
                    Button("Unpin") { store.setPinned(false, ids, in: workspace.id) }
                }
                Menu("Move to Collection") {
                    Button("No Collection") { store.move(ids, toCollection: nil, in: workspace.id) }
                    ForEach(workspace.collections) { collection in
                        Button(collection.name) { store.move(ids, toCollection: collection.id, in: workspace.id) }
                    }
                }
                Divider()
                Button("Remove from Workspace") { store.remove(ids, from: workspace.id) }
            }
        } primaryAction: { ids in
            rows.filter { ids.contains($0.id) }.forEach(open)
        }
    }
}

/// The smart rules of a workspace, with switches to pause them.
private struct RulesPanel: View {
    let workspace: Workspace
    @Binding var isAddingRule: Bool
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Smart Rules")
                    .font(.headline)
                Text("New files that match are added automatically. Downloads, Desktop and Documents are checked every 10 minutes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(workspace.rules) { rule in
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: Binding(
                            get: { rule.isEnabled },
                            set: { store.setRule(rule.id, enabled: $0, in: workspace.id) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.condition.summary)
                                    .fontWeight(.semibold)
                                Text(verbatim: "→ " + (workspace.collection(rule.collectionID)?.name ?? workspace.name))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        Text(rule.isEnabled ? String(localized: "\(rule.matchCount) files added") : String(localized: "Paused"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12))
                    }
                    .contextMenu {
                        Button("Delete Rule", role: .destructive) {
                            store.removeRule(rule.id, from: workspace.id)
                        }
                    }
                }
                Button("New Rule…") { isAddingRule = true }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension RuleCondition {
    /// A short sentence describing the rule, such as “Names containing “facture” (PDF)”.
    var summary: String {
        switch self {
        case .nameContains(let text, let extensions):
            let base = String(localized: "Names containing “\(text)”")
            return extensions.isEmpty ? base : "\(base) (\(extensions.map { $0.uppercased() }.joined(separator: ", ")))"
        case .tagged(let tag):
            return String(localized: "Files tagged “\(tag)”")
        case .category(let category):
            return String(localized: "All \(category.title)")
        }
    }
}
