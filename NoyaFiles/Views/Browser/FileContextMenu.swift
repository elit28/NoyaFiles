import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The right-click menu for items, or for the folder itself when nothing is clicked.
struct FileContextMenu: View {
    let model: BrowserModel
    let ids: Set<BrowserNode.ID>

    var body: some View {
        if ids.isEmpty {
            Button("New Folder…") { model.isNewFolderPresented = true }
            Divider()
            Button("Show in Finder") { model.revealInFinder([]) }
            Button("Refresh") { model.reload() }
        } else {
            Button("Open") { model.open(ids) }
                .keyboardShortcut("o")
            let urls = model.items(for: ids).map(\.url)
            if !urls.isEmpty {
                OpenWithMenu(urls: urls)
                Button("Quick Look") {
                    model.selection = ids
                    model.toggleQuickLook()
                }
                .keyboardShortcut(.space, modifiers: [])
                Divider()
                Button("Show in Finder") { model.revealInFinder(ids) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Copy Path") { model.copyPaths(ids) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                AddToWorkspaceMenu(urls: urls)
                Divider()
                Button("Move to Trash", role: .destructive) { model.requestMoveToTrash(ids) }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
}

/// The apps that can open some files, the default one first, as in the Finder.
struct OpenWithMenu: View {
    let urls: [URL]

    var body: some View {
        if let first = urls.first {
            let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: first)
            let others = NSWorkspace.shared.urlsForApplications(toOpen: first)
                .filter { $0 != defaultApp }
                .sorted { Self.name(of: $0).localizedStandardCompare(Self.name(of: $1)) == .orderedAscending }
            Menu("Open With") {
                if let defaultApp {
                    Button {
                        open(with: defaultApp)
                    } label: {
                        let name = Self.name(of: defaultApp)
                        Label { Text("\(name) (default)") } icon: { Self.icon(of: defaultApp) }
                    }
                    Divider()
                }
                ForEach(others.prefix(20), id: \.self) { app in
                    Button {
                        open(with: app)
                    } label: {
                        Label { Text(Self.name(of: app)) } icon: { Self.icon(of: app) }
                    }
                }
                if !others.isEmpty { Divider() }
                Button("Other…", action: chooseApp)
            }
        }
    }

    private func open(with app: URL) {
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = String(localized: "Open")
        if panel.runModal() == .OK, let app = panel.url {
            open(with: app)
        }
    }

    static func name(of app: URL) -> String {
        FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(of app: URL) -> Image {
        let icon = NSWorkspace.shared.icon(forFile: app.path).copy() as? NSImage ?? NSImage()
        icon.size = NSSize(width: 16, height: 16)
        return Image(nsImage: icon)
    }
}
