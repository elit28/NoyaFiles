import Foundation
import NoyaCore

/// One row of the list view or one tile of the grid view.
///
/// A node is either a real file system item or a group of items, such as
/// "all the images in this folder". Every value the views sort or display is
/// computed once, when the node is built.
struct BrowserNode: Identifiable, Hashable {
    enum Content: Hashable {
        case item(FileItem)
        case category(FileCategory)
        case dateBucket(DateBucket)
    }

    let id: String
    let content: Content
    let name: String
    let modificationDate: Date
    let addedDate: Date
    /// Size in bytes, or -1 while a folder has not been measured yet.
    let size: Int64
    let kindDescription: String
    /// The size as shown in the list view.
    let sizeText: String
    /// The short caption shown under a grid tile.
    let detailText: String
    var children: [BrowserNode]?

    var item: FileItem? {
        switch content {
        case .item(let item): item
        case .category, .dateBucket: nil
        }
    }

    var isGroup: Bool { item == nil }
    var isFolder: Bool { item?.isFolder ?? false }
    var isHidden: Bool { item?.isHidden ?? false }
}
