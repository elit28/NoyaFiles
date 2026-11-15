import SwiftUI

/// Lets the user type a path, such as `~/Projects`, and jump to it.
struct GoToFolderSheet: View {
    let model: BrowserModel

    @Environment(\.dismiss) private var dismiss
    @State private var path = ""
    @State private var isNotFound = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Folder")
                .font(.headline)

            TextField("Path", text: $path, prompt: Text(verbatim: "~/Downloads"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)
                .onSubmit(go)
                .onChange(of: path) {
                    isNotFound = false
                }

            if isNotFound {
                Text("No folder exists at this path.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Go", action: go)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedPath.isEmpty)
            }
        }
        .padding(20)
        .onAppear {
            path = (model.location.url.path as NSString).abbreviatingWithTildeInPath
        }
    }

    private var trimmedPath: String {
        path.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func go() {
        let expanded = (trimmedPath as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard
            !expanded.isEmpty,
            FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            isNotFound = true
            return
        }
        model.navigate(to: URL(fileURLWithPath: expanded, isDirectory: true))
        dismiss()
    }
}

/// Asks for the name of a new folder in the current folder.
struct NewFolderSheet: View {
    let model: BrowserModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = String(localized: "untitled folder")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Folder")
                .font(.headline)
            Text("In \(model.title)")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 340)
                .onSubmit(create)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }

    private func create() {
        if model.createFolder(named: name) {
            dismiss()
        }
    }
}
