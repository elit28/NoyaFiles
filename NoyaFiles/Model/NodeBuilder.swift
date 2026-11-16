import Foundation
import NoyaCore
import UniformTypeIdentifiers

/// Turns folder contents into the rows and groups the browser displays.
@MainActor
enum NodeBuilder {
    static func build(
        items: [FileItem],
        grouping: GroupingMode,
        measurements: [URL: FolderSizer.Measurement],
        sortOrder: [KeyPathComparator<BrowserNode>],
        foldersFirst: Bool = true,
        now: Date
    ) -> [BrowserNode] {
        func makeNode(_ item: FileItem) -> BrowserNode {
            node(for: item, measurement: measurements[item.url])
        }

        switch grouping {
        case .flat:
            return sorted(items.map(makeNode), by: sortOrder, foldersFirst: foldersFirst)

        case .kind:
            let folders = items.filter(\.isFolder).map(makeNode).sorted(using: sortOrder)
            let groups = Grouping.byCategory(items, measurements: measurements).map { group in
                groupNode(
                    id: "category:\(group.category.rawValue)",
                    content: .category(group.category),
                    name: group.category.title,
                    bytes: group.bytes,
                    children: group.items.map(makeNode).sorted(using: sortOrder)
                )
            }
            return folders + groups

        case .date:
            return Grouping.byDate(items, now: now).map { group in
                let children = sorted(group.items.map(makeNode), by: sortOrder, foldersFirst: foldersFirst)
                return groupNode(
                    id: "date:\(group.bucket.rawValue)",
                    content: .dateBucket(group.bucket),
                    name: group.bucket.title,
                    bytes: children.reduce(0) { $0 + max($1.size, 0) },
                    children: children
                )
            }
        }
    }

    static func node(for item: FileItem, measurement: FolderSizer.Measurement?) -> BrowserNode {
        let size: Int64 = item.isContainer ? (measurement?.bytes ?? -1) : item.size
        let sizeText = size >= 0 ? size.formattedByteCount : "—"

        let detailText: String
        switch item.kind {
        case .folder:
            if let measurement {
                detailText = [
                    String(localized: "\(measurement.itemCount) items"),
                    measurement.bytes.formattedByteCount,
                ].joined(separator: " · ")
            } else {
                detailText = String(localized: "Folder")
            }
        case .package, .file:
            detailText = sizeText
        }

        return BrowserNode(
            id: item.url.path,
            content: .item(item),
            name: item.name,
            modificationDate: item.modificationDate ?? .distantPast,
            addedDate: item.addedDate ?? item.creationDate ?? .distantPast,
            size: size,
            kindDescription: KindDescriber.description(for: item),
            sizeText: sizeText,
            detailText: detailText,
            children: nil
        )
    }

    private static func groupNode(
        id: String,
        content: BrowserNode.Content,
        name: String,
        bytes: Int64,
        children: [BrowserNode]
    ) -> BrowserNode {
        let count = children.count
        return BrowserNode(
            id: id,
            content: content,
            name: name,
            modificationDate: children.map(\.modificationDate).max() ?? .distantPast,
            addedDate: children.map(\.addedDate).max() ?? .distantPast,
            size: bytes,
            kindDescription: String(localized: "\(count) items"),
            sizeText: bytes.formattedByteCount,
            detailText: [String(localized: "\(count) files"), bytes.formattedByteCount].joined(separator: " · "),
            children: children
        )
    }

    /// Sorts nodes, optionally keeping folders above everything else as most file managers do.
    static func sorted(
        _ nodes: [BrowserNode],
        by sortOrder: [KeyPathComparator<BrowserNode>],
        foldersFirst: Bool
    ) -> [BrowserNode] {
        guard foldersFirst else { return nodes.sorted(using: sortOrder) }
        return nodes.filter(\.isFolder).sorted(using: sortOrder)
            + nodes.filter { !$0.isFolder }.sorted(using: sortOrder)
    }
}

/// Describes the kind of an item the way the system does, such as "PDF document".
@MainActor
enum KindDescriber {
    private static var descriptionsByExtension: [String: String] = [:]

    static func description(for item: FileItem) -> String {
        switch item.kind {
        case .folder:
            return String(localized: "Folder")
        case .package where item.fileExtension == "app":
            return String(localized: "Application")
        case .package, .file:
            break
        }

        let fileExtension = item.fileExtension
        guard !fileExtension.isEmpty else { return String(localized: "Document") }
        if let cached = descriptionsByExtension[fileExtension] { return cached }

        let description = UTType(filenameExtension: fileExtension)?.localizedDescription
            ?? String(localized: "\(fileExtension.uppercased()) file")
        descriptionsByExtension[fileExtension] = description
        return description
    }
}
