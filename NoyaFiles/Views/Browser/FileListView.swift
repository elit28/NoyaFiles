import SwiftUI

/// Folder contents as a sortable table. Groups can be expanded to show their files.
struct FileListView: View {
    @Bindable var model: BrowserModel

    var body: some View {
        Table(
            model.rootNodes,
            children: \.children,
            selection: $model.selection,
            sortOrder: $model.sortOrder
        ) {
            TableColumn("Name", value: \.name) { node in
                NameCell(node: node)
            }
            .width(min: 180, ideal: 320)

            TableColumn("Date Modified", value: \.modificationDate) { node in
                Text(DateText.string(for: node.modificationDate))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Date Added", value: \.addedDate) { node in
                Text(DateText.string(for: node.addedDate))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Size", value: \.size) { node in
                Text(node.sizeText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Kind", value: \.kindDescription) { node in
                Text(node.kindDescription)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 140)
        }
        .contextMenu(forSelectionType: BrowserNode.ID.self) { ids in
            FileContextMenu(model: model, ids: ids)
        } primaryAction: { ids in
            model.open(ids)
        }
        .onKeyPress(.space) {
            model.toggleQuickLook()
            return .handled
        }
    }
}

private struct NameCell: View {
    let node: BrowserNode

    var body: some View {
        HStack(spacing: 7) {
            NodeIcon(node: node, side: 18)
            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .opacity(node.isHidden ? 0.55 : 1)
    }
}
