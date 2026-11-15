import AppKit
import SwiftUI

/// The three steps shown the first time NOYA Files opens: what it does, access to files, preferences.
struct WelcomeView: View {
    let finish: () -> Void
    @State private var step = 0
    @State private var hasFullDiskAccess = PrivacyStatus.hasFullDiskAccess()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: IntroStep()
                case 1: AccessStep(hasAccess: hasFullDiskAccess)
                default: PreferencesStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 44)
            .padding(.top, 34)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            .id(step)

            Divider()
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index == step ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.18)))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("Step \(step + 1) of 3"))
                Spacer()
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 640, height: 580)
        .animation(.easeInOut(duration: 0.25), value: step)
        .task(id: step) {
            // Notices when the person grants Full Disk Access in System Settings.
            guard step == 1 else { return }
            while !Task.isCancelled {
                hasFullDiskAccess = PrivacyStatus.hasFullDiskAccess()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch step {
        case 0:
            Button("Continue") { step = 1 }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        case 1:
            if hasFullDiskAccess {
                Button("Continue") { step = 2 }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Later") { step = 2 }
                Button("Open Settings") {
                    NSWorkspace.shared.open(PrivacyStatus.fullDiskAccessSettingsURL)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        default:
            Button("Get Started", action: finish)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Steps

private struct IntroStep: View {
    var body: some View {
        VStack(spacing: 26) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 6) {
                Text("Welcome to NOYA Files")
                    .font(.largeTitle.weight(.bold))
                Text("A smarter home for your files.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 18) {
                Feature(symbol: "chart.pie", title: Text("See what takes up space"), detail: Text("Each folder shows its size and what it holds."))
                Feature(symbol: "tray.and.arrow.down", title: Text("Tidy up your downloads"), detail: Text("A clear preview before anything moves."))
                Feature(symbol: "lock.shield", title: Text("Everything stays on your Mac"), detail: Text("No account, and no file is ever sent anywhere."))
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Feature: View {
    let symbol: String
    let title: Text
    let detail: Text

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                title.fontWeight(.semibold)
                detail.foregroundStyle(.secondary)
            }
        }
    }
}

private struct AccessStep: View {
    let hasAccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: hasAccess ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(hasAccess ? AnyShapeStyle(Color.green) : AnyShapeStyle(.tint))
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow access to your files")
                    .font(.title.weight(.bold))
                Text("To measure all your folders and open the Trash, NOYA Files needs Full Disk Access. You can take it back at any time.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                Instruction(number: 1, text: Text("Open **System Settings › Privacy & Security**."))
                Instruction(number: 2, text: Text("Choose **Full Disk Access**."))
                Instruction(number: 3, text: Text("Turn on **NOYA Files**, then come back here."))
            }
            HStack(spacing: 8) {
                if hasAccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Access granted. Thank you!")
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for permission…")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("Without this access, NOYA Files still works: macOS will ask for permission folder by folder.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct Instruction: View {
    let number: Int
    let text: Text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: "\(number)")
                .font(.callout.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundStyle(.tint)
            text
        }
    }
}

private struct PreferencesStep: View {
    @State private var language = AppLanguage.stored
    @AppStorage(PreferenceKey.viewMode) private var viewMode = ViewMode.grid
    @AppStorage(PreferenceKey.grouping) private var grouping = GroupingMode.kind
    @AppStorage(PreferenceKey.sidebarVisibility) private var visibility = SidebarVisibility.standard
    @AppStorage(PreferenceKey.assistantEnabled) private var isAssistantEnabled = false

    private struct Favorite: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let symbol: String
    }

    private let favorites = [
        Favorite(id: "desktop", title: "Desktop", symbol: "menubar.dock.rectangle"),
        Favorite(id: "documents", title: "Documents", symbol: "doc"),
        Favorite(id: "downloads", title: "Downloads", symbol: "arrow.down.circle"),
        Favorite(id: "applications", title: "Applications", symbol: "square.grid.2x2"),
        Favorite(id: "pictures", title: "Pictures", symbol: "photo"),
        Favorite(id: "movies", title: "Movies", symbol: "film"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your preferences")
                    .font(.title.weight(.bold))
                Text("You can change everything later in Settings (⌘,).")
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 18) {
                GridRow {
                    Text("Language")
                        .gridColumnAlignment(.trailing)
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("Language", selection: $language) {
                            Text("System").tag(AppLanguage.system)
                            Text(verbatim: "Français").tag(AppLanguage.french)
                            Text(verbatim: "English").tag(AppLanguage.english)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                        if language != AppLanguage.atLaunch {
                            Text("Takes effect the next time you open NOYA Files.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                GridRow {
                    Text("Default view")
                    Picker("Default view", selection: viewBinding) {
                        Text("Grid by Kind").tag(ViewMode.grid)
                        Text("List").tag(ViewMode.list)
                        Text("Columns").tag(ViewMode.columns)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                GridRow(alignment: .top) {
                    Text("Sidebar favorites")
                    FlowRow(spacing: 8) {
                        ForEach(favorites) { favorite in
                            Toggle(isOn: binding(for: favorite.id)) {
                                Label(favorite.title, systemImage: favorite.symbol)
                            }
                            .toggleStyle(.button)
                        }
                    }
                    .frame(maxWidth: 380, alignment: .leading)
                }
                GridRow(alignment: .top) {
                    Text("AI Assistant")
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Turn on the assistant", isOn: $isAssistantEnabled)
                        Text("Optional. Off by default. Everything runs on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onChange(of: language) {
            language.save()
        }
    }

    private var viewBinding: Binding<ViewMode> {
        Binding(
            get: { viewMode },
            set: { mode in
                viewMode = mode
                if mode == .grid { grouping = .kind }
            }
        )
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { visibility.shows(id) },
            set: { visibility.set(id, visible: $0) }
        )
    }
}
