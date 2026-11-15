import NoyaCore
import SwiftUI

extension FileCategory {
    var title: String {
        switch self {
        case .documents: String(localized: "Documents")
        case .pdfs: String(localized: "PDFs")
        case .images: String(localized: "Images")
        case .screenshots: String(localized: "Screenshots")
        case .videos: String(localized: "Videos")
        case .audio: String(localized: "Audio")
        case .archives: String(localized: "Archives")
        case .installers: String(localized: "Installers")
        case .code: String(localized: "Code")
        case .other: String(localized: "Other")
        }
    }

    var symbolName: String {
        switch self {
        case .documents: "doc.text"
        case .pdfs: "doc.richtext"
        case .images: "photo"
        case .screenshots: "camera.viewfinder"
        case .videos: "film"
        case .audio: "music.note"
        case .archives: "archivebox"
        case .installers: "shippingbox"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .other: "ellipsis"
        }
    }

    var tint: Color {
        switch self {
        case .documents: Color(hex: 0x3B82F6)
        case .pdfs: Color(hex: 0xEF4444)
        case .images: Color(hex: 0xF59E0B)
        case .screenshots: Color(hex: 0x10B981)
        case .videos: Color(hex: 0x8B5CF6)
        case .audio: Color(hex: 0xEC4899)
        case .archives: Color(hex: 0xB7791F)
        case .installers: Color(hex: 0x64748B)
        case .code: Color(hex: 0x6366F1)
        case .other: Color(hex: 0x9CA3AF)
        }
    }
}

extension DateBucket {
    var title: String {
        switch self {
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .previous7Days: String(localized: "Previous 7 Days")
        case .previous30Days: String(localized: "Previous 30 Days")
        case .earlierThisYear: String(localized: "Earlier This Year")
        case .older: String(localized: "Older")
        }
    }
}

extension GroupingMode {
    var title: String {
        switch self {
        case .flat: String(localized: "None")
        case .kind: String(localized: "Kind")
        case .date: String(localized: "Date")
        }
    }
}

extension AppearancePreference {
    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    /// `nil` follows the system appearance.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension SortField {
    var title: String {
        switch self {
        case .name: String(localized: "Name")
        case .dateModified: String(localized: "Date Modified")
        case .dateAdded: String(localized: "Date Added")
        case .size: String(localized: "Size")
        case .kind: String(localized: "Kind")
        }
    }
}

extension BrowserScope {
    /// A short label for a narrowed view, or `nil` when the whole folder is shown.
    var title: String? {
        switch self {
        case .everything: nil
        case .category(let category): category.title
        case .staleFiles(let days): String(localized: "Older than \(days) days")
        }
    }

    var symbolName: String {
        switch self {
        case .everything: "folder"
        case .category(let category): category.symbolName
        case .staleFiles: "clock.arrow.circlepath"
        }
    }
}

extension BrowserError {
    var title: String {
        switch self {
        case .permissionDenied: String(localized: "NOYA Files can't open this folder")
        case .notFound: String(localized: "This folder no longer exists")
        case .other: String(localized: "This folder couldn't be opened")
        }
    }

    var message: String {
        switch self {
        case .permissionDenied:
            String(localized: "macOS needs your permission. Allow access when asked, or turn on Full Disk Access for NOYA Files in Privacy & Security settings.")
        case .notFound:
            String(localized: "It may have been moved, renamed or deleted.")
        case .other(let description):
            description
        }
    }

    var symbolName: String {
        switch self {
        case .permissionDenied: "lock"
        case .notFound: "questionmark.folder"
        case .other: "exclamationmark.triangle"
        }
    }
}

extension Color {
    /// A colour from a 24-bit RGB value, such as `0x3B82F6`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
