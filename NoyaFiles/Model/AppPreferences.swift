import AppKit
import SwiftUI

/// The keys under which preferences are stored in `UserDefaults`.
enum PreferenceKey {
    static let appearance = "appearance"
    static let accent = "appearance.accent"
    static let iconSize = "browser.iconSize"
    static let startLocation = "general.startLocation"
    static let measureFolders = "browser.measureFolders"
    static let foldersFirst = "browser.foldersFirst"
    static let viewMode = "browser.viewMode"
    static let grouping = "browser.grouping"
    static let showHidden = "browser.showHidden"
    static let insightsVisible = "browser.insightsVisible"
    static let lastPath = "browser.lastPath"
    static let sidebarVisibility = "sidebar.visibility"
    static let dualPane = "window.dualPane"
}

/// The window appearance chosen by the user, or the system's.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    /// Applies the preference to every window of the app.
    @MainActor
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// The colour of selections, buttons and highlights.
enum AccentPreference: String, CaseIterable, Identifiable {
    case teal
    case blue
    case purple
    case pink
    case orange
    case graphite

    var id: Self { self }

    var title: String {
        switch self {
        case .teal: String(localized: "Teal")
        case .blue: String(localized: "NOYA Blue")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        case .orange: String(localized: "Orange")
        case .graphite: String(localized: "Graphite")
        }
    }

    var color: Color {
        switch self {
        case .teal: .accentColor
        case .blue: Color(light: 0x0043E4, dark: 0x5B8CFF)
        case .purple: Color(light: 0x7C3AED, dark: 0xA78BFA)
        case .pink: Color(light: 0xDB2777, dark: 0xF472B6)
        case .orange: Color(light: 0xC2410C, dark: 0xFB923C)
        case .graphite: Color(light: 0x52525B, dark: 0xA1A1AA)
        }
    }
}

/// Where a new window starts.
enum StartLocation: String, CaseIterable, Identifiable {
    case last
    case downloads
    case home
    case desktop
    case documents

    var id: Self { self }

    var title: String {
        switch self {
        case .last: String(localized: "Last Folder Opened")
        case .downloads: String(localized: "Downloads")
        case .home: String(localized: "Home")
        case .desktop: String(localized: "Desktop")
        case .documents: String(localized: "Documents")
        }
    }

    var url: URL? {
        switch self {
        case .last: nil
        case .downloads: .downloadsDirectory
        case .home: .homeDirectory
        case .desktop: .desktopDirectory
        case .documents: .documentsDirectory
        }
    }
}

/// The language of the app, which takes effect at the next launch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case french
    case english

    var id: Self { self }

    /// The language the app was launched in, captured once.
    @MainActor static let atLaunch = AppLanguage.stored

    static var stored: AppLanguage {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        switch (domain?["AppleLanguages"] as? [String])?.first {
        case "fr"?: return .french
        case "en"?: return .english
        default: return .system
        }
    }

    var title: String {
        switch self {
        case .system: String(localized: "System Language")
        case .french: "Français"
        case .english: "English"
        }
    }

    func save() {
        switch self {
        case .system: UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .french: UserDefaults.standard.set(["fr"], forKey: "AppleLanguages")
        case .english: UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
    }
}

/// Which optional places the sidebar hides, stored as one string.
struct SidebarVisibility: RawRepresentable, Equatable {
    var hidden: Set<String>

    static let standard = SidebarVisibility(hidden: ["pictures", "movies", "music"])

    init(hidden: Set<String>) {
        self.hidden = hidden
    }

    init?(rawValue: String) {
        hidden = Set(rawValue.split(separator: ",").map(String.init))
    }

    var rawValue: String {
        hidden.sorted().joined(separator: ",")
    }

    func shows(_ id: String) -> Bool {
        !hidden.contains(id)
    }

    mutating func set(_ id: String, visible: Bool) {
        if visible {
            hidden.remove(id)
        } else {
            hidden.insert(id)
        }
    }
}

/// Whether the app can read every file, which macOS calls Full Disk Access.
enum PrivacyStatus {
    static let fullDiskAccessSettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    /// Probes a file that macOS only lets apps with Full Disk Access open.
    static func hasFullDiskAccess() -> Bool {
        let probe = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        let descriptor = open(probe.path, O_RDONLY)
        guard descriptor >= 0 else { return false }
        close(descriptor)
        return true
    }
}

extension Color {
    /// A colour that adapts to light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
