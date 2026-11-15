import Foundation
import NoyaCore

/// Which part of a folder's contents the browser shows.
enum BrowserScope: Hashable, Sendable {
    case everything
    case category(FileCategory)
    case staleFiles(days: Int)
}

/// A place in the browser's history: a folder, possibly narrowed to some of its files.
struct BrowserLocation: Hashable, Sendable {
    var url: URL
    var scope: BrowserScope = .everything
}

enum ViewMode: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: Self { self }
}

enum GroupingMode: String, CaseIterable, Identifiable {
    case flat
    case kind
    case date

    var id: Self { self }
}

enum SortField: String, CaseIterable, Identifiable {
    case name
    case dateModified
    case dateAdded
    case size
    case kind

    var id: Self { self }

    init?(keyPath: PartialKeyPath<BrowserNode>) {
        let fields: [(keyPath: PartialKeyPath<BrowserNode>, field: SortField)] = [
            (\BrowserNode.name, .name),
            (\BrowserNode.modificationDate, .dateModified),
            (\BrowserNode.addedDate, .dateAdded),
            (\BrowserNode.size, .size),
            (\BrowserNode.kindDescription, .kind),
        ]
        guard let match = fields.first(where: { $0.keyPath == keyPath }) else { return nil }
        self = match.field
    }

    func comparator(order: SortOrder) -> KeyPathComparator<BrowserNode> {
        switch self {
        case .name: KeyPathComparator(\.name, comparator: .localizedStandard, order: order)
        case .dateModified: KeyPathComparator(\.modificationDate, order: order)
        case .dateAdded: KeyPathComparator(\.addedDate, order: order)
        case .size: KeyPathComparator(\.size, order: order)
        case .kind: KeyPathComparator(\.kindDescription, comparator: .localizedStandard, order: order)
        }
    }
}

/// The window appearance chosen by the user, or the system's.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: Self { self }
}

enum LoadState: Equatable {
    case loading
    case loaded
    case failed(BrowserError)
}

enum BrowserError: Error, Equatable, Sendable {
    case permissionDenied
    case notFound
    case other(String)

    init(_ error: any Error) {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError:
                self = .permissionDenied
                return
            case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
                self = .notFound
                return
            default:
                break
            }
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           underlying.code == Int(EPERM) || underlying.code == Int(EACCES) {
            self = .permissionDenied
            return
        }
        self = .other(error.localizedDescription)
    }
}

/// A titled group of tiles in the grid view.
struct GridSection: Identifiable {
    let id: String
    let title: String?
    let nodes: [BrowserNode]
}

extension URL {
    /// The standard form of a folder URL, so the same folder always compares equal.
    var canonicalDirectory: URL {
        URL(fileURLWithPath: standardizedFileURL.path, isDirectory: true)
    }
}
