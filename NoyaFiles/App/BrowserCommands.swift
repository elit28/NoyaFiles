import AppKit
import SwiftUI

/// The File, View and Go menu items that act on the focused browser window.
struct BrowserCommands: Commands {
    @FocusedValue(\.browserModel) private var model: BrowserModel?
    @FocusedValue(\.windowModel) private var window: WindowModel?
    @AppStorage(PreferenceKey.appearance) private var appearance = AppearancePreference.system

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("Find…") { window?.openSearch() }
                .keyboardShortcut("f")
                .disabled(window == nil)
            Button("Tidy Up Downloads…") { window?.isTidyPresented = true }
                .keyboardShortcut("t", modifiers: [.command, .option])
                .disabled(window == nil)
            Button("Open") { openSelection() }
                .keyboardShortcut("o")
                .disabled(!hasSelection)
            Button("Show in Finder") { model?.revealInFinder(model?.selection ?? []) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model == nil)
            Button("Copy Path") { model?.copyPaths(model?.selection ?? []) }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(!hasSelection)
            Button("Quick Look") { model?.toggleQuickLook() }
                .keyboardShortcut("y")
                .disabled(!hasSelection)
            Divider()
            Button("Move to Trash") { moveSelectionToTrash() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!hasSelection)
        }

        CommandGroup(after: .sidebar) {
            Divider()
            Button("as List") { model?.viewMode = .list }
                .keyboardShortcut("1")
                .disabled(model == nil)
            Button("as Grid") { model?.viewMode = .grid }
                .keyboardShortcut("2")
                .disabled(model == nil)
            Button("as Columns") { model?.viewMode = .columns }
                .keyboardShortcut("3")
                .disabled(model == nil)
            Divider()
            Button(window?.isDualPane == true ? LocalizedStringKey("Hide Dual Pane") : LocalizedStringKey("Show Dual Pane")) {
                window?.isDualPane.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(window == nil)
            Button("Switch Pane") { window?.toggleActivePane() }
                .keyboardShortcut(.tab, modifiers: .control)
                .disabled(window?.isDualPane != true)
            Button("Copy to Other Pane") { window?.transferSelection(.copy) }
                .keyboardShortcut(Self.functionKey(NSF5FunctionKey), modifiers: [])
                .disabled(window?.isDualPane != true || !hasSelection)
            Button("Move to Other Pane") { window?.transferSelection(.move) }
                .keyboardShortcut(Self.functionKey(NSF6FunctionKey), modifiers: [])
                .disabled(window?.isDualPane != true || !hasSelection)
            Divider()
            Button(insightsTitle) { model?.isInsightsVisible.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(model == nil)
            Button(hiddenFilesTitle) { model?.showHidden.toggle() }
                .keyboardShortcut(".", modifiers: [.command, .shift])
                .disabled(model == nil)
            Picker("Appearance", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            Divider()
            Button("Refresh") { model?.reload() }
                .keyboardShortcut("r")
                .disabled(model == nil)
        }

        CommandMenu("Go") {
            Button("Back") { model?.goBack() }
                .keyboardShortcut("[")
                .disabled(!(model?.canGoBack ?? false))
            Button("Forward") { model?.goForward() }
                .keyboardShortcut("]")
                .disabled(!(model?.canGoForward ?? false))
            Button("Enclosing Folder") { model?.goUp() }
                .keyboardShortcut(.upArrow)
                .disabled(!(model?.canGoUp ?? false))
            Divider()
            Button("Home") { go(to: .homeDirectory) }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Desktop") { go(to: .desktopDirectory) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Documents") { go(to: .documentsDirectory) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Downloads") { go(to: .downloadsDirectory) }
                .keyboardShortcut("l", modifiers: [.command, .option])
            Button("Applications") { go(to: URL(fileURLWithPath: "/Applications", isDirectory: true)) }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            Divider()
            Button("Go to Folder…") { model?.isGoToFolderPresented = true }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(model == nil)
        }
    }

    private static func functionKey(_ code: Int) -> KeyEquivalent {
        KeyEquivalent(Character(UnicodeScalar(UInt32(code)) ?? " "))
    }

    private var hasSelection: Bool {
        !(model?.selection.isEmpty ?? true)
    }

    private var insightsTitle: LocalizedStringKey {
        model?.isInsightsVisible == true ? "Hide Insights" : "Show Insights"
    }

    private var hiddenFilesTitle: LocalizedStringKey {
        model?.showHidden == true ? "Hide Hidden Files" : "Show Hidden Files"
    }

    private func openSelection() {
        guard let model else { return }
        model.open(model.selection)
    }

    /// Moves the selection to the Trash, unless the user is editing text.
    ///
    /// ⌘⌫ also deletes to the start of the line in text fields, and menu shortcuts
    /// are handled before text fields see the key, so the shortcut is passed on to
    /// the field instead of trashing files by surprise.
    private func moveSelectionToTrash() {
        if NSApp.keyWindow?.firstResponder is NSText {
            NSApp.sendAction(#selector(NSResponder.deleteToBeginningOfLine(_:)), to: nil, from: nil)
            return
        }
        guard let model else { return }
        model.moveToTrash(model.selection)
    }

    private func go(to url: URL) {
        model?.navigate(to: url)
    }
}
