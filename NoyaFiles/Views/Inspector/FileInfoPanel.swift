import NoyaCore
import SwiftUI

/// Everything about the selected file: preview, kind, dates, origin and tags.
struct FileInfoPanel: View {
    let item: FileItem
    let model: BrowserModel

    @State private var details: FileDetails?
    @State private var isAddingTag = false
    @State private var newTag = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                preview
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.headline)
                        .textSelection(.enabled)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
                actions
                facts
                tags
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: item) {
            details = nil
            details = await FileDetailsLoader.load(item.url)
        }
    }

    private var subtitle: String {
        let kind = KindDescriber.description(for: item)
        let bytes = item.isContainer ? model.measurements[item.url]?.bytes : item.size
        guard let bytes else { return kind }
        return [kind, bytes.formattedByteCount].joined(separator: " · ")
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            if item.kind == .file {
                FileThumbnail(item: item, side: 220)
            } else {
                Image(nsImage: IconCache.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Open") { model.open(urls: [item.url]) }
            ShareLink(item: item.url) {
                Text("Share")
            }
            Menu {
                Button("Show in Finder") { model.revealInFinder(urls: [item.url]) }
                Button("Copy Path") { model.copyPaths(urls: [item.url]) }
                AddToWorkspaceMenu(urls: [item.url])
                Divider()
                Button("Move to Trash", role: .destructive) { model.moveToTrash(urls: [item.url]) }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More actions")
        }
        .controlSize(.regular)
    }

    private var facts: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 7) {
            if let added = item.addedDate {
                fact("Added", DateText.string(for: added))
            }
            if let modified = item.modificationDate {
                fact("Modified", DateText.string(for: modified))
            }
            if let created = item.creationDate {
                fact("Created", DateText.string(for: created))
            }
            if let width = details?.pixelWidth, let height = details?.pixelHeight {
                fact("Dimensions", "\(width) × \(height)")
            }
            if let duration = details?.duration {
                fact("Duration", Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated)))
            }
            if let pages = details?.pageCount {
                fact("Pages", pages.formatted())
            }
            if let source = details?.downloadedFrom {
                fact("Downloaded From", source)
            }
            fact("Where", FileManager.default.displayName(atPath: item.url.deletingLastPathComponent().path))
        }
        .font(.callout)
    }

    private func fact(_ label: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private var tags: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            FlowRow(spacing: 6) {
                ForEach(details?.tags ?? [], id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                        Button {
                            updateTags { $0.removeAll { $0 == tag } }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .help("Remove Tag")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                }
                Button("Add Tag…") { isAddingTag = true }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $isAddingTag, arrowEdge: .bottom) {
                        TextField("Tag", text: $newTag)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .padding()
                            .onSubmit(addTag)
                    }
            }
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        newTag = ""
        isAddingTag = false
        guard !tag.isEmpty else { return }
        updateTags { tags in
            if !tags.contains(tag) { tags.append(tag) }
        }
    }

    private func updateTags(_ change: (inout [String]) -> Void) {
        var tags = details?.tags ?? []
        change(&tags)
        do {
            try FileTagger.setTags(tags, on: item.url)
            details?.tags = tags
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

/// Lays out its children in rows, wrapping to a new row when one is full.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
