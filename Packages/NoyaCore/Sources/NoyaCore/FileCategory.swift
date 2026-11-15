import Foundation

/// A broad family of files, used to group, colour and summarise folder contents.
///
/// Classification only looks at the file name, so it is cheap, deterministic and
/// works the same on every platform.
public enum FileCategory: String, CaseIterable, Sendable, Codable {
    case documents
    case pdfs
    case images
    case screenshots
    case videos
    case audio
    case archives
    case installers
    case code
    case other

    /// Returns the category that best describes a file with the given name.
    public static func classify(fileName: String) -> FileCategory {
        let fileExtension = pathExtension(of: fileName)
        if imageExtensions.contains(fileExtension) {
            return isScreenshotName(fileName) ? .screenshots : .images
        }
        return categoriesByExtension[fileExtension] ?? .other
    }

    /// The lowercased extension of a file name, or an empty string when there is none.
    ///
    /// A leading dot does not start an extension, so `.zshrc` has no extension.
    public static func pathExtension(of fileName: String) -> String {
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return "" }
        return fileName[fileName.index(after: dot)...].lowercased()
    }

    /// Whether a file name follows the naming pattern of common screenshot tools.
    static func isScreenshotName(_ fileName: String) -> Bool {
        let name = fileName.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        return screenshotPrefixes.contains { name.hasPrefix($0) }
    }

    private static let screenshotPrefixes = [
        "screenshot",
        "screen shot",
        "capture d'écran",
        "capture d'ecran",
        "cleanshot",
        "bildschirmfoto",
        "captura de pantalla",
        "schermafbeelding",
        "istantanea",
    ]

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp",
        "svg", "ico", "avif", "raw", "dng", "cr2", "cr3", "nef", "arw", "psd",
    ]

    private static let extensionsByCategory: [FileCategory: [String]] = [
        .documents: [
            "txt", "rtf", "rtfd", "md", "markdown", "doc", "docx", "pages", "odt",
            "xls", "xlsx", "numbers", "ods", "csv", "tsv",
            "ppt", "pptx", "key", "odp", "epub",
        ],
        .pdfs: ["pdf"],
        .videos: ["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "mpg", "mpeg", "3gp"],
        .audio: ["mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "ogg", "opus", "wma", "caf"],
        .archives: ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst"],
        .installers: ["dmg", "pkg", "mpkg", "xip", "app"],
        .code: [
            "swift", "py", "js", "mjs", "ts", "tsx", "jsx", "html", "css", "scss", "json",
            "xml", "yml", "yaml", "toml", "sh", "zsh", "rb", "go", "rs", "java", "kt",
            "c", "h", "cpp", "hpp", "m", "mm", "php", "sql", "ipynb",
        ],
    ]

    private static let categoriesByExtension: [String: FileCategory] = {
        var lookup: [String: FileCategory] = [:]
        for (category, extensions) in extensionsByCategory {
            for fileExtension in extensions {
                lookup[fileExtension] = category
            }
        }
        return lookup
    }()
}
