import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case sidebar
    case privacy
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .appearance: String(localized: "Appearance")
        case .sidebar: String(localized: "Sidebar")
        case .privacy: String(localized: "Privacy")
        case .advanced: String(localized: "Advanced")
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "circle.lefthalf.filled"
        case .sidebar: "sidebar.left"
        case .privacy: "hand.raised"
        case .advanced: "slider.horizontal.3"
        }
    }
}

/// The Settings window, opened with ⌘,.
struct SettingsView: View {
    @State private var section: SettingsSection? = .general
    @AppStorage(PreferenceKey.accent) private var accent = AccentPreference.teal

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch section ?? .general {
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .sidebar: SidebarSettings()
                case .privacy: PrivacySettings()
                case .advanced: AdvancedSettings()
                }
            }
            .formStyle(.grouped)
            .navigationTitle((section ?? .general).title)
        }
        .frame(width: 780, height: 560)
        .tint(accent.color)
    }
}

private struct GeneralSettings: View {
    @AppStorage(PreferenceKey.startLocation) private var startLocation = StartLocation.last
    @AppStorage(PreferenceKey.viewMode) private var viewMode = ViewMode.grid
    @AppStorage(PreferenceKey.grouping) private var grouping = GroupingMode.kind
    @AppStorage(PreferenceKey.showHidden) private var showHidden = false
    @AppStorage(PreferenceKey.measureFolders) private var measureFolders = true
    @AppStorage(PreferenceKey.insightsVisible) private var insightsVisible = true
    @AppStorage(PreferenceKey.foldersFirst) private var foldersFirst = true
    @State private var language = AppLanguage.stored

    var body: some View {
        Form {
            Section {
                Picker("New windows open", selection: $startLocation) {
                    ForEach(StartLocation.allCases) { location in
                        Text(location.title).tag(location)
                    }
                }
                Picker("Default view", selection: $viewMode) {
                    Text("Grid").tag(ViewMode.grid)
                    Text("List").tag(ViewMode.list)
                }
                Picker("Group by default", selection: $grouping) {
                    ForEach(GroupingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker(selection: $language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                } label: {
                    Text("Language")
                    if language != AppLanguage.atLaunch {
                        Text("Takes effect the next time you open NOYA Files.")
                    }
                }
                .onChange(of: language) {
                    language.save()
                }
            }

            Section {
                Toggle("Show hidden files", isOn: $showHidden)
                Toggle(isOn: $measureFolders) {
                    Text("Calculate folder sizes")
                    Text("Can keep the disk busy in very large folders.")
                }
                Toggle("Show the Insights panel in new windows", isOn: $insightsVisible)
                Toggle("Keep folders on top", isOn: $foldersFirst)
            }
        }
    }
}

private struct AppearanceSettings: View {
    @AppStorage(PreferenceKey.appearance) private var appearance = AppearancePreference.system
    @AppStorage(PreferenceKey.accent) private var accent = AccentPreference.teal
    @AppStorage(PreferenceKey.iconSize) private var iconSize = 96.0

    var body: some View {
        Form {
            Section("Theme") {
                HStack(spacing: 18) {
                    ForEach(AppearancePreference.allCases) { preference in
                        ThemeChoice(preference: preference, isSelected: appearance == preference) {
                            appearance = preference
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                LabeledContent("Accent color") {
                    HStack(spacing: 10) {
                        ForEach(AccentPreference.allCases) { choice in
                            Button {
                                accent = choice
                            } label: {
                                Circle()
                                    .fill(choice.color)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        if accent == choice {
                                            Circle().strokeBorder(.primary, lineWidth: 2).padding(-4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(choice.title)
                            .accessibilityLabel(choice.title)
                            .accessibilityAddTraits(accent == choice ? .isSelected : [])
                        }
                    }
                }
                LabeledContent("Icon size") {
                    Slider(value: $iconSize, in: 64...160, step: 8) {
                        Text("Icon size")
                    } minimumValueLabel: {
                        Image(systemName: "square.grid.3x3")
                    } maximumValueLabel: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                }
            }
        }
        .onChange(of: appearance) {
            appearance.apply()
        }
    }
}

private struct ThemeChoice: View {
    let preference: AppearancePreference
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                swatch
                    .frame(width: 96, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.15)), lineWidth: isSelected ? 3 : 1)
                    }
                Text(preference.title)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var swatch: some View {
        switch preference {
        case .system:
            HStack(spacing: 0) {
                Color(white: 0.98)
                Color(white: 0.12)
            }
        case .light:
            Color(white: 0.98)
        case .dark:
            Color(white: 0.12)
        }
    }
}

private struct SidebarSettings: View {
    @AppStorage(PreferenceKey.sidebarVisibility) private var visibility = SidebarVisibility.standard

    private struct Entry: Identifiable {
        let id: String
        let title: LocalizedStringKey
    }

    private let favorites = [
        Entry(id: "desktop", title: "Desktop"),
        Entry(id: "documents", title: "Documents"),
        Entry(id: "downloads", title: "Downloads"),
        Entry(id: "applications", title: "Applications"),
        Entry(id: "pictures", title: "Pictures"),
        Entry(id: "movies", title: "Movies"),
        Entry(id: "music", title: "Music"),
    ]

    private let locations = [
        Entry(id: "icloud", title: "iCloud Drive"),
        Entry(id: "home", title: "Home"),
        Entry(id: "volumes", title: "Disks"),
        Entry(id: "trash", title: "Trash"),
        Entry(id: "disk", title: "Disk space"),
    ]

    var body: some View {
        Form {
            Section("Favorites") {
                ForEach(favorites) { entry in
                    Toggle(entry.title, isOn: binding(for: entry.id))
                }
            }
            Section("Locations") {
                ForEach(locations) { entry in
                    Toggle(entry.title, isOn: binding(for: entry.id))
                }
            }
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { visibility.shows(id) },
            set: { visibility.set(id, visible: $0) }
        )
    }
}

private struct PrivacySettings: View {
    @State private var hasFullDiskAccess = PrivacyStatus.hasFullDiskAccess()

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    if hasFullDiskAccess {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not allowed", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                } label: {
                    Text("Full Disk Access")
                    Text("Lets NOYA Files measure every folder and open the Trash.")
                }
                HStack {
                    Button("Open Privacy Settings") {
                        NSWorkspace.shared.open(PrivacyStatus.fullDiskAccessSettingsURL)
                    }
                    Button("Check Again") {
                        hasFullDiskAccess = PrivacyStatus.hasFullDiskAccess()
                    }
                }
            }
            Section {
                Text("NOYA Files works entirely on this Mac. It has no account and sends none of your files anywhere.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AdvancedSettings: View {
    @State private var isConfirmingReset = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Button("Reset…") { isConfirmingReset = true }
                } label: {
                    Text("Reset all settings")
                    Text("Your files are not affected.")
                }
            }
        }
        .confirmationDialog("Reset all settings?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive) {
                if let identifier = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: identifier)
                }
                AppearancePreference.system.apply()
            }
        } message: {
            Text("NOYA Files goes back to how it was on first launch.")
        }
    }
}
