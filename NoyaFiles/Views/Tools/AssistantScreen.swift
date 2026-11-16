import AppKit
import SwiftUI

/// The AI assistant: the files it found on the left, the conversation on the right.
struct AssistantScreen: View {
    let window: WindowModel
    @AppStorage(PreferenceKey.assistantEnabled) private var isEnabled = false

    var body: some View {
        Group {
            if isEnabled {
                AssistantWorkspace(assistant: AssistantModel.shared, window: window)
            } else {
                AssistantIntro { isEnabled = true }
            }
        }
        .navigationTitle("AI Assistant")
    }
}

private struct AssistantWorkspace: View {
    let assistant: AssistantModel
    let window: WindowModel

    var body: some View {
        HStack(spacing: 0) {
            AssistantResults(assistant: assistant)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            AssistantChat(assistant: assistant, window: window)
                .frame(width: 360)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    assistant.clear()
                } label: {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
                .help("Start a new conversation")
                .disabled(assistant.messages.isEmpty)
            }
        }
        .task {
            // A launch argument used by the automated screenshots.
            if assistant.messages.isEmpty, let prompt = UserDefaults.standard.string(forKey: "noya.assistantPrompt") {
                assistant.send(prompt)
            }
        }
    }
}

// MARK: - Introduction

/// Shown until the person turns the assistant on: it is optional and off by default.
private struct AssistantIntro: View {
    let enable: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 46))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("AI Assistant")
                        .font(.largeTitle.weight(.bold))
                    Text("Ask in your own words, such as “Find my 2026 invoices and put them in the Taxes workspace”. The assistant proposes a plan and changes nothing without your agreement.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 520)
                }
                VStack(alignment: .leading, spacing: 14) {
                    point("lock.fill", Text("Everything stays on this Mac"), Text("No account, and no file is ever sent over the internet."))
                    point("checkmark.shield", Text("You stay in control"), Text("Each change is shown first, and can be undone right after."))
                    point("cpu", Text("Apple Intelligence when available"), Text(verbatim: intelligenceStatus))
                }
                .frame(maxWidth: 460, alignment: .leading)
                Button(action: enable) {
                    Text("Turn On the Assistant")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Optional feature, off by default. You can turn it off in Settings › AI Assistant.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }

    private var intelligenceStatus: String {
        guard let reason = LocalIntelligence.unavailableReason else {
            return String(localized: "Apple Intelligence is ready on this Mac.")
        }
        return reason + " " + String(localized: "The assistant then uses simple rules, which understand fewer requests.")
    }

    private func point(_ symbol: String, _ title: Text, _ detail: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                title.fontWeight(.semibold)
                detail.foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Results

private struct AssistantResults: View {
    let assistant: AssistantModel

    var body: some View {
        if let title = assistant.resultsTitle {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 10) {
                        Text(title)
                            .font(.title2.weight(.semibold))
                        if assistant.isWorking {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    if let subtitle = assistant.resultsSubtitle {
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                Divider()
                List(assistant.files) { file in
                    AssistantFileRow(file: file, workspace: assistant.targetWorkspace)
                }
                .listStyle(.inset)
            }
        } else {
            ContentUnavailableView {
                Label("Ask the Assistant", systemImage: "sparkles")
            } description: {
                Text("Describe what you are looking for or what you want to tidy up. The files it finds appear here.")
            }
        }
    }
}

private struct AssistantFileRow: View {
    let file: AssistantFile
    let workspace: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                if let proposed = file.proposedFileName {
                    // The proposed name in full, with the current one crossed out below it.
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.tint)
                        Text(proposed)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help("Name proposed from the content")
                    let currentName = Text(file.name).strikethrough()
                    let place = file.place
                    Text("\(currentName) · \(place)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(file.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(file.place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let workspace {
                Text(verbatim: "+ \(workspace)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { NSWorkspace.shared.open(file.url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(file.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
        }
    }
}

// MARK: - Conversation

private struct AssistantChat: View {
    let assistant: AssistantModel
    let window: WindowModel
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    /// Requests to send with one click, in the language of the app, as the person would type them.
    private var suggestions: [String] {
        [
            String(localized: "Summarize this PDF"),
            String(localized: "Rename my screenshots"),
            String(localized: "What can I delete?"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Assistant", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Label(
                    LocalIntelligence.isAvailable ? LocalizedStringKey("Apple Intelligence, on this Mac") : LocalizedStringKey("Processed on this Mac"),
                    systemImage: "lock.fill"
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if assistant.messages.isEmpty {
                            Text("Ask for files by kind, year or name, and say where to gather them. For example: “Find my 2026 invoices and put them in the Taxes workspace”.")
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        ForEach(assistant.messages) { message in
                            MessageBubble(message: message) { action in
                                if action == .openFreeUpSpace {
                                    window.destination = .tool(.freeUpSpace)
                                }
                                assistant.perform(action, in: message)
                            }
                            .id(message.id)
                        }
                        if assistant.isWorking {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Working…").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                }
                .onChange(of: assistant.messages.count) {
                    if let id = assistant.messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 10) {
                FlowRow(spacing: 6) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            send(suggestion)
                        } label: {
                            Text(verbatim: suggestion)
                                .font(.caption)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask the Assistant…", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($isFocused)
                        .onSubmit { send(draft) }
                        .padding(8)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Button {
                        send(draft)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || assistant.isWorking)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Send")
                }
                Text("Optional feature, off by default. The assistant proposes; nothing changes without your agreement.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .background(Color.primary.opacity(0.02))
        .onAppear { isFocused = true }
    }

    private func send(_ text: String) {
        let selection = window.activeBrowser.selectedItems.map(\.url)
        assistant.send(text, selection: selection)
        draft = ""
    }
}

private struct MessageBubble: View {
    let message: AssistantMessage
    let perform: (AssistantAction) -> Void

    var body: some View {
        HStack {
            if message.role == .person { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if !message.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(message.steps.enumerated()), id: \.offset) { _, step in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                                Text(step)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                if !message.actions.isEmpty {
                    FlowRow(spacing: 8) {
                        ForEach(message.actions, id: \.self) { action in
                            actionButton(action)
                        }
                    }
                    .disabled(message.isSettled)
                }
            }
            .padding(12)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(message.role == .person ? AnyShapeStyle(Color.white) : AnyShapeStyle(HierarchicalShapeStyle.primary))
            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }

    private var background: AnyShapeStyle {
        message.role == .person ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.06))
    }

    @ViewBuilder
    private func actionButton(_ action: AssistantAction) -> some View {
        switch action {
        case .apply:
            Button("Apply") { perform(action) }
                .buttonStyle(.borderedProminent)
        case .applyWithoutRenaming:
            Button("Without Renaming") { perform(action) }
        case .cancel:
            Button("Cancel") { perform(action) }
        case .chooseFile:
            Button("Choose a File…") { perform(action) }
        case .openFreeUpSpace:
            Button("Open Free Up Space") { perform(action) }
                .buttonStyle(.borderedProminent)
        }
    }
}
