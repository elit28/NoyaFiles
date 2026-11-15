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
