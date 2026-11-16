import AppKit
import NoyaCore
import SwiftUI

/// Folder contents as tiles, in titled sections.
struct FileGridView: View {
    @Bindable var model: BrowserModel

    @AppStorage(PreferenceKey.iconSize) private var iconSize = 96.0

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: iconSize + 36, maximum: iconSize + 56), spacing: 16, alignment: .top)]
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(model.gridSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            if let title = section.title {
                                SectionHeader(title: title, count: section.nodes.count)
                            }
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                                ForEach(section.nodes) { node in
                                    tile(for: node)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selection = []
                }
                .contextMenu {
                    FileContextMenu(model: model, ids: [])
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            model.toggleQuickLook()
            return .handled
        }
    }

    private func tile(for node: BrowserNode) -> some View {
        GridTile(node: node, isSelected: model.selection.contains(node.id), iconSize: iconSize)
            .onTapGesture(count: 2) {
                model.open([node.id])
            }
            .simultaneousGesture(TapGesture().onEnded {
                model.select(node.id, toggling: NSEvent.modifierFlags.contains(.command))
            })
            .contextMenu {
                FileContextMenu(model: model, ids: model.contextTargets(for: node.id))
            }
            .modifier(FileDragSource(url: node.item?.url))
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(count, format: .number)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GridTile: View {
    let node: BrowserNode
    let isSelected: Bool
    let iconSize: CGFloat

    private var artHeight: CGFloat { iconSize * 80 / 96 }

    var body: some View {
        VStack(spacing: 6) {
            artwork
                .frame(width: iconSize, height: artHeight)
                .padding(6)
                .background(
                    isSelected ? Color.primary.opacity(0.09) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            Text(node.name)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear),
                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                )

            Text(node.detailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
        }
        .frame(width: iconSize + 36)
        .contentShape(Rectangle())
        .opacity(node.isHidden ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var artwork: some View {
        switch node.content {
        case .category(let category):
            CategoryFolderArt(category: category)
                .scaleEffect(iconSize / 96)
        case .dateBucket:
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        case .item(let item):
            if item.kind == .file {
                FileThumbnail(item: item, side: artHeight)
            } else {
                Image(nsImage: IconCache.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

/// Lets files be dragged to other apps, such as Mail or the Finder.
private struct FileDragSource: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            content.onDrag {
                NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }
        } else {
            content
        }
    }
}
