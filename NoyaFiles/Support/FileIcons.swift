import AppKit
import NoyaCore
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

/// System icons for files and folders, cached by file type where possible.
@MainActor
enum IconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for item: FileItem) -> NSImage {
        let usesTypeIcon = item.kind == .file && !item.fileExtension.isEmpty
        let key = (usesTypeIcon ? "type:\(item.fileExtension)" : "path:\(item.url.path)") as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let icon: NSImage
        if usesTypeIcon, let type = UTType(filenameExtension: item.fileExtension) {
            icon = NSWorkspace.shared.icon(for: type)
        } else {
            icon = NSWorkspace.shared.icon(forFile: item.url.path)
        }
        cache.setObject(icon, forKey: key)
        return icon
    }
}

/// Quick Look previews of file contents, such as a photo or the first page of a PDF.
enum ThumbnailLoader {
    private struct Thumbnail: @unchecked Sendable {
        let image: CGImage
    }

    @MainActor private static let cache = NSCache<NSString, NSImage>()

    /// Returns a preview of the file, or `nil` when Quick Look has none.
    @MainActor
    static func thumbnail(for item: FileItem, side: CGFloat, scale: CGFloat) async -> NSImage? {
        let stamp = item.modificationDate?.timeIntervalSince1970 ?? 0
        let key = "\(item.url.path)|\(stamp)|\(Int(side * scale))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let thumbnail = await generate(for: item.url, side: side, scale: scale) else { return nil }
        let size = NSSize(
            width: CGFloat(thumbnail.image.width) / scale,
            height: CGFloat(thumbnail.image.height) / scale
        )
        let image = NSImage(cgImage: thumbnail.image, size: size)
        cache.setObject(image, forKey: key)
        return image
    }

    private static func generate(for url: URL, side: CGFloat, scale: CGFloat) async -> Thumbnail? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation.map { Thumbnail(image: $0.cgImage) })
            }
        }
    }
}

/// A file's Quick Look preview, falling back to its icon.
struct FileThumbnail: View {
    let item: FileItem
    let side: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            } else {
                Image(nsImage: IconCache.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: side, height: side)
        .task(id: item) {
            guard item.kind == .file else { return }
            thumbnail = await ThumbnailLoader.thumbnail(for: item, side: side, scale: displayScale)
        }
    }
}

/// The icon shown next to a name in the list view.
struct NodeIcon: View {
    let node: BrowserNode
    let side: CGFloat

    var body: some View {
        switch node.content {
        case .item(let item):
            Image(nsImage: IconCache.icon(for: item))
                .resizable()
                .interpolation(.high)
                .frame(width: side, height: side)
        case .category(let category):
            RoundedRectangle(cornerRadius: side * 0.25, style: .continuous)
                .fill(category.tint.gradient)
                .overlay {
                    Image(systemName: category.symbolName)
                        .font(.system(size: side * 0.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: side, height: side)
        case .dateBucket:
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: side, height: side)
        }
    }
}
