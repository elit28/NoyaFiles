import AppKit
import SwiftUI

struct SidebarView: View {
    let sidebar: SidebarModel
    @Binding var selection: SidebarSelection?
    @AppStorage(PreferenceKey.sidebarVisibility) private var visibility = SidebarVisibility.standard
    @Environment(WorkspaceStore.self) private var workspaces
    @Environment(SavedSearchStore.self) private var savedSearches
    @State private var isCreatingWorkspace = false

    var body: some View {
        List(selection: $selection) {
            if visibility.shows("workspaces") {
                Section("Workspaces") {
                    ForEach(workspaces.workspaces) { workspace in
                        Label {
                            Text(workspace.name)
                        } icon: {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(workspace.color.color)
                                .frame(width: 11, height: 11)
                        }
                        .badge(workspace.entries.count)
                        .tag(SidebarSelection.workspace(workspace.id))
                    }
                    Button {
                        isCreatingWorkspace = true
                    } label: {
                        Label("New Workspace", systemImage: "plus")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Search") {
                Label("Advanced Search", systemImage: "magnifyingglass")
                    .tag(SidebarSelection.search)
                ForEach(savedSearches.searches) { search in
                    Label(search.name, systemImage: "text.magnifyingglass")
                        .tag(SidebarSelection.savedSearch(search.id))
                        .contextMenu {
                            Button("Delete Saved Search", role: .destructive) {
                                savedSearches.delete(search.id)
                            }
                        }
                }
            }

            Section("Favorites") {
                ForEach(sidebar.favorites.filter { visibility.shows($0.key) }) { item in
                    Label(item.title, systemImage: item.symbolName)
                        .tag(SidebarSelection.folder(item.url))
                }
            }

            Section("Locations") {
                ForEach(sidebar.locations.filter { visibility.shows($0.key) }) { item in
                    Label(item.title, systemImage: item.symbolName)
                        .tag(SidebarSelection.folder(item.url))
                }
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $isCreatingWorkspace) {
            WorkspaceEditorSheet(workspace: nil) { id in
                selection = .workspace(id)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BrandHeader()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if visibility.shows("disk") {
                DiskUsageFooter(disk: sidebar.disk)
            }
        }
        .task {
            while !Task.isCancelled {
                sidebar.refreshDiskUsage()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            sidebar.refresh()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            sidebar.refresh()
        }
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 22, height: 22)
            Text(verbatim: "NOYA Files")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct DiskUsageFooter: View {
    let disk: DiskUsage?

    var body: some View {
        if let disk {
            HStack(spacing: 10) {
                Image(systemName: "internaldrive")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(disk.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    UsageBar(fraction: disk.usedFraction, fill: .tint)
                    Text("\(disk.availableBytes.formattedByteCount) free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }
    }
}
