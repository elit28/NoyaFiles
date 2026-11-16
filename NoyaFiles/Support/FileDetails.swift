import AVFoundation
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Details shown for a single file, read from its contents and metadata.
struct FileDetails: Sendable, Equatable {
    var pixelWidth: Int?
    var pixelHeight: Int?
    var duration: TimeInterval?
    var pageCount: Int?
    /// The website the file was downloaded from, such as `drive.example.com`.
    var downloadedFrom: String?
    var tags: [String] = []
}

enum FileDetailsLoader {
    /// Reads the details of a file. Anything that cannot be read is left empty.
    static func load(_ url: URL) async -> FileDetails {
        var details = FileDetails()
        details.tags = (try? url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? []

        if let metadata = NSMetadataItem(url: url),
           let sources = metadata.value(forAttribute: "kMDItemWhereFroms") as? [String],
           let source = sources.first {
            details.downloadedFrom = URL(string: source)?.host() ?? source
        }

        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .image) == true {
            readImageSize(of: url, into: &details)
        }
        if type?.conforms(to: .pdf) == true {
            details.pageCount = PDFDocument(url: url)?.pageCount
        }
        if type?.conforms(to: .audiovisualContent) == true {
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration), duration.isNumeric {
                details.duration = duration.seconds
            }
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let size = try? await track.load(.naturalSize) {
                details.pixelWidth = Int(abs(size.width))
                details.pixelHeight = Int(abs(size.height))
            }
        }
        return details
    }

    private static func readImageSize(of url: URL, into details: inout FileDetails) {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return }
        details.pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
        details.pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
    }
}

enum FileTagger {
    /// Replaces the Finder tags of a file.
    static func setTags(_ tags: [String], on url: URL) throws {
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }
}
