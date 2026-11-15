import NoyaCore
import SwiftUI

/// Creates a workspace, or edits the name, colour and description of an existing one.
struct WorkspaceEditorSheet: View {
    /// The workspace to edit, or `nil` to create one.
    let workspace: Workspace?
    var onCreate: (UUID) -> Void = { _ in }

    @Environment(WorkspaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var summary = ""
    @State private var color = WorkspaceColor.teal
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(workspace == nil ? LocalizedStringKey("New Workspace") : LocalizedStringKey("Edit Workspace"))
                .font(.title3.weight(.semibold))
            Form {
                TextField("Name", text: $name, prompt: Text("Freelance"))
                TextField("Description", text: $summary, prompt: Text("Clients, quotes and invoices"))
                LabeledContent("Color") {
                    HStack(spacing: 8) {
                        ForEach(WorkspaceColor.allCases) { choice in
                            Button {
                                color = choice
                            } label: {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(choice.color)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        if color == choice {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .strokeBorder(.primary, lineWidth: 2)
                                                .padding(-3)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice.rawValue)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 170)

            HStack {
                if workspace != nil {
                    Button("Delete Workspace…", role: .destructive) { isConfirmingDelete = true }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(workspace == nil ? LocalizedStringKey("Create") : LocalizedStringKey("Save"), action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if let workspace {
                name = workspace.name
                summary = workspace.summary
                color = workspace.color
            }
        }
        .confirmationDialog("Delete this workspace?", isPresented: $isConfirmingDelete) {
            Button("Delete Workspace", role: .destructive) {
                if let workspace { store.deleteWorkspace(workspace.id) }
                dismiss()
            }
        } message: {
            Text("Its files are not deleted: only the workspace is.")
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)
        if var workspace {
            workspace.name = trimmedName
            workspace.summary = trimmedSummary
            workspace.color = color
            store.update(workspace)
        } else {
            onCreate(store.createWorkspace(name: trimmedName, summary: trimmedSummary, color: color))
        }
        dismiss()
    }
}

/// Creates a smart rule that adds matching files to a workspace.
struct RuleEditorSheet: View {
    let workspace: Workspace

    private enum Kind: String, CaseIterable, Identifiable {
        case name, tag, category
        var id: Self { self }
    }

    @Environment(WorkspaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind = Kind.name
    @State private var text = ""
    @State private var extensions = ""
    @State private var category = FileCategory.pdfs
    @State private var collectionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Smart Rule")
                .font(.title3.weight(.semibold))
            Form {
                Picker("Add files", selection: $kind) {
                    Text("whose name contains").tag(Kind.name)
                    Text("tagged").tag(Kind.tag)
                    Text("of the kind").tag(Kind.category)
                }
                switch kind {
                case .name:
                    TextField("Text", text: $text, prompt: Text("invoice"))
                    TextField("Only these extensions", text: $extensions, prompt: Text("pdf, docx"))
                case .tag:
                    TextField("Tag", text: $text, prompt: Text("atlas"))
                case .category:
                    Picker("Kind", selection: $category) {
                        ForEach(FileCategory.allCases, id: \.self) { category in
                            Text(category.title).tag(category)
                        }
                    }
                }
                Picker("Into", selection: $collectionID) {
                    Text("The whole workspace").tag(UUID?.none)
                    ForEach(workspace.collections) { collection in
                        Text(collection.name).tag(UUID?.some(collection.id))
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 210)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Rule", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(kind != .category && text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func create() {
        let condition: RuleCondition
        switch kind {
        case .name:
            let allowed = extensions
                .split(whereSeparator: { $0 == "," || $0 == " " })
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")) }
                .filter { !$0.isEmpty }
            condition = .nameContains(text.trimmingCharacters(in: .whitespaces), extensions: allowed)
        case .tag:
            condition = .tagged(text.trimmingCharacters(in: .whitespaces))
        case .category:
            condition = .category(category)
        }
        store.addRule(WorkspaceRule(condition: condition, collectionID: collectionID), to: workspace.id)
        dismiss()
    }
}

/// The “Add to Workspace” submenu for files.
struct AddToWorkspaceMenu: View {
    let urls: [URL]
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        if !store.workspaces.isEmpty, !urls.isEmpty {
            Menu("Add to Workspace") {
                ForEach(store.workspaces) { workspace in
                    if workspace.collections.isEmpty {
                        Button(workspace.name) { store.add(urls, to: workspace.id) }
                    } else {
                        Menu(workspace.name) {
                            Button("No Collection") { store.add(urls, to: workspace.id) }
                            Divider()
                            ForEach(workspace.collections) { collection in
                                Button(collection.name) {
                                    store.add(urls, to: workspace.id, collection: collection.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
