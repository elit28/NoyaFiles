import AppKit
import NoyaCore
import Observation
import UniformTypeIdentifiers

/// A file the assistant found, with the clearer name it proposes, if any.
struct AssistantFile: Identifiable, Hashable {
    let url: URL
    /// A new name without the extension.
    var proposedName: String?

    var id: URL { url }
    var name: String { url.lastPathComponent }

    var proposedFileName: String? {
        guard let proposedName else { return nil }
        return url.pathExtension.isEmpty ? proposedName : proposedName + "." + url.pathExtension
    }

    /// Where the file is, such as “Documents › Administratif”.
    var place: String {
        let folder = url.deletingLastPathComponent().standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let homeComponents = home.pathComponents
        let components = folder.pathComponents
        guard components.starts(with: homeComponents), components.count > homeComponents.count else {
            return FileManager.default.displayName(atPath: folder.path)
        }
        var names = Array(components.dropFirst(homeComponents.count))
        names[0] = FileManager.default.displayName(atPath: home.appendingPathComponent(names[0]).path)
        return names.joined(separator: " › ")
    }
}

/// Something the person can do in reply to the assistant.
enum AssistantAction: Hashable {
    case apply
    case applyWithoutRenaming
    case cancel
    case chooseFile
    case openFreeUpSpace
}

struct AssistantMessage: Identifiable {
    enum Role {
        case person
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: AttributedString
    var steps: [AttributedString] = []
    var actions: [AssistantAction] = []
    /// Whether the actions were used or are no longer relevant.
    var isSettled = false
}

/// What the assistant proposes to do, waiting for the person's agreement.
private struct AssistantPlan {
    enum Kind {
        case gather
        case renameScreenshots
    }

    let kind: Kind
    let workspaceName: String?
    let workspaceExists: Bool
    let collectionName: String?
    let messageID: UUID
}

/// The assistant of NOYA Files: it understands simple requests, proposes a plan, and changes
/// nothing until the person agrees. Everything runs on this Mac.
@MainActor
@Observable
final class AssistantModel {
    static let shared = AssistantModel()

    private(set) var messages: [AssistantMessage] = []
    private(set) var files: [AssistantFile] = []
    private(set) var resultsTitle: String?
    private(set) var resultsSubtitle: String?
    /// The workspace the files will go to, shown next to each of them.
    private(set) var targetWorkspace: String?
    private(set) var isWorking = false

    @ObservationIgnored private var plan: AssistantPlan?
    @ObservationIgnored private var work: Task<Void, Never>?

    static let searchFolders: [URL] = [.downloadsDirectory, .documentsDirectory, .desktopDirectory]

    var renameCount: Int { files.filter { $0.proposedName != nil }.count }

    // MARK: - Requests

    /// Answers a request. `selection` is what is selected in the browser, used for “summarize this PDF”.
    func send(_ request: String, selection: [URL] = []) {
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settleOpenMessages()
        messages.append(AssistantMessage(role: .person, text: AttributedString(trimmed)))

        let workspaces = WorkspaceStore.shared.workspaces.map(\.name)
        switch AssistantParser.parse(trimmed, workspaces: workspaces) {
        case .gather(let request):
            gather(request)
        case .renameScreenshots:
            renameScreenshots()
        case .summarize:
            if let url = selection.first(where: { Self.canSummarize($0) }) {
                summarize(url)
            } else {
                reply(String(localized: "Select a PDF or a text file in a folder, then ask again, or choose one now."), actions: [.chooseFile])
            }
        case .freeUpSpace:
            suggestFreeingSpace()
        case .unknown:
            reply(String(localized: "I did not understand. Try “Find my invoices from 2026”, “Rename my screenshots” or “What can I delete?”."))
        }
    }

    func perform(_ action: AssistantAction, in message: AssistantMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].isSettled = true
        }
        switch action {
        case .apply: apply(renaming: true)
        case .applyWithoutRenaming: apply(renaming: false)
        case .cancel:
            plan = nil
            reply(String(localized: "All right, nothing was changed."))
        case .chooseFile:
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.pdf, .text]
            panel.directoryURL = .documentsDirectory
            if panel.runModal() == .OK, let url = panel.url {
                summarize(url)
            }
        case .openFreeUpSpace:
            break // The screen opens the tool.
        }
    }

    func clear() {
        work?.cancel()
        messages = []
        files = []
        resultsTitle = nil
        resultsSubtitle = nil
        targetWorkspace = nil
        plan = nil
        isWorking = false
    }

    // MARK: - Gathering files

    private func gather(_ request: AssistantRequest) {
        guard let query = request.spotlightQuery else { return }
        work?.cancel()
        isWorking = true
        files = []
        targetWorkspace = request.workspaceName
        let words = request.keywords.joined(separator: " ")
        let what = request.topic?.pluralTitle ?? String(localized: "files matching “\(words)”")
        resultsTitle = String(localized: "Looking for \(what)…")
        resultsSubtitle = Self.folderList

        work = Task { [weak self] in
            let hits = await Spotlight.find(query, in: Self.searchFolders, limit: 400)
            let urls = hits.map(\.url)
                .filter { !$0.path.contains("/Library/") && !$0.path.contains(".app/") }
                .filter { url in
                    let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let dates = [values?.creationDate, values?.contentModificationDate].compactMap { $0 }
                    return request.matchesYear(fileName: url.lastPathComponent, dates: dates)
                }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            guard let self, !Task.isCancelled else { return }
            self.files = urls.map { AssistantFile(url: $0) }
            let count = urls.count
            self.resultsTitle = request.topic.map { $0.foundTitle(count) } ?? String(localized: "\(count) files found")

            if count == 0 {
                self.isWorking = false
                self.reply(String(localized: "I found no \(what) in \(Self.folderList)."))
                return
            }

            // Proposes names for the files whose name says nothing, from their contents.
            if request.renames, let topic = request.topic, topic.isDocument {
                let unclear = self.files.filter { FileNaming.isUnclear($0.name) }.prefix(25)
                for file in unclear {
                    if Task.isCancelled { return }
                    let name = await LocalIntelligence.proposedName(for: file.url, title: topic.singularTitle, example: topic.example)
                    if let name, name != file.url.deletingPathExtension().lastPathComponent,
                       let index = self.files.firstIndex(where: { $0.url == file.url }) {
                        self.files[index].proposedName = name
                    }
                }
            }
            self.isWorking = false
            self.proposeGatherPlan(request, count: count)
        }
    }

    private func proposeGatherPlan(_ request: AssistantRequest, count: Int) {
        let renames = renameCount
        let found = request.topic.map { $0.foundPhrase(count) } ?? String(localized: "\(count) files")
        var steps: [AttributedString] = []
        var collectionName: String?

        if let workspace = request.workspaceName {
            let collection = request.topic?.collectionTitle ?? String(localized: "Found by the Assistant")
            collectionName = collection
            let existing = WorkspaceStore.shared.workspaces.first { $0.name.compare(workspace, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            if existing == nil {
                steps.append(Self.markdown(String(localized: "Create the workspace **\(workspace)** with a collection **\(collection)**.")))
            } else if existing?.collections.contains(where: { $0.name == collection }) == false {
                steps.append(Self.markdown(String(localized: "Create the collection **\(collection)** in the workspace \(workspace).")))
            }
            steps.append(Self.markdown(String(localized: "Add the \(count) files to it. The originals stay where they are.")))
        }
        if renames > 0 {
            steps.append(Self.markdown(String(localized: "Rename \(renames) files with unclear names, from their contents.")))
        }

        let intro = String(localized: "I found **\(found)** in \(Self.folderList).")
        guard !steps.isEmpty else {
            reply(intro + " " + String(localized: "Open them from the list, or name a workspace to gather them in, such as “… in the workspace Taxes”."))
            return
        }
        var actions: [AssistantAction] = [.apply]
        if renames > 0, request.workspaceName != nil { actions.append(.applyWithoutRenaming) }
        actions.append(.cancel)
        let message = AssistantMessage(
            role: .assistant,
            text: Self.markdown(intro + " " + String(localized: "Here is what I suggest:")),
            steps: steps,
            actions: actions
        )
        messages.append(message)
        plan = AssistantPlan(
            kind: .gather,
            workspaceName: request.workspaceName,
            workspaceExists: request.workspaceExists,
            collectionName: collectionName,
            messageID: message.id
        )
    }

    // MARK: - Screenshots

    private func renameScreenshots() {
        work?.cancel()
        isWorking = true
        files = []
        targetWorkspace = nil
        resultsTitle = String(localized: "Looking for screenshots…")
        resultsSubtitle = Self.folderList
        let prefix = AssistantTopic.screenshots.singularTitle

        work = Task { [weak self] in
            let folders = Self.searchFolders + [.picturesDirectory]
            let hits = await Spotlight.find("kMDItemIsScreenCapture == 1", in: folders, limit: 300)
            let urls = hits.map(\.url).filter { FileNaming.isUnclear($0.lastPathComponent) }.prefix(40)
            guard let self, !Task.isCancelled else { return }
            self.files = urls.map { AssistantFile(url: $0) }
            self.resultsTitle = String(localized: "\(urls.count) screenshots with a default name")
            guard !urls.isEmpty else {
                self.isWorking = false
                self.reply(String(localized: "All your screenshots already have a clear name."))
                return
            }
            for url in urls {
                if Task.isCancelled { return }
                let name = await LocalIntelligence.proposedName(for: url, title: prefix, example: AssistantTopic.screenshots.example)
                if let name, let index = self.files.firstIndex(where: { $0.url == url }) {
                    self.files[index].proposedName = name
                }
            }
            self.isWorking = false
            let renames = self.renameCount
            guard renames > 0 else {
                self.reply(String(localized: "I could not read enough text in these screenshots to name them."))
                return
            }
            let message = AssistantMessage(
                role: .assistant,
                text: Self.markdown(String(localized: "I can give **\(renames) screenshots** a name taken from what they show.")),
                steps: [Self.markdown(String(localized: "Rename them in place. You can undo it right after."))],
                actions: [.apply, .cancel]
            )
            self.messages.append(message)
            self.plan = AssistantPlan(kind: .renameScreenshots, workspaceName: nil, workspaceExists: false, collectionName: nil, messageID: message.id)
        }
    }

    // MARK: - Applying

    private func apply(renaming: Bool) {
        guard let plan else { return }
        self.plan = nil

        // Renames first, so the workspace points to the new names.
        var renamed: [(from: URL, to: URL)] = []
        var finalURLs: [URL] = []
        for file in files {
            guard renaming, let newName = file.proposedFileName, newName != file.name else {
                finalURLs.append(file.url)
                continue
            }
            let destination = FileOperationCenter.uniqueDestination(for: newName, in: file.url.deletingLastPathComponent())
            do {
                try FileManager.default.moveItem(at: file.url, to: destination)
                renamed.append((file.url, destination))
                finalURLs.append(destination)
            } catch {
                finalURLs.append(file.url)
            }
        }
        let renamedSources = Set(renamed.map(\.from))
        files = zip(files, finalURLs).map { file, url in
            AssistantFile(url: url, proposedName: renamedSources.contains(file.url) ? nil : file.proposedName)
        }

        var workspaceID: UUID?
        var addedEntries: Set<String> = []
        if plan.kind == .gather, let name = plan.workspaceName {
            let store = WorkspaceStore.shared
            let id = store.workspaces.first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }?.id
                ?? store.createWorkspace(name: name, summary: String(localized: "Created by the Assistant"), color: .teal)
            var collectionID: UUID?
            if let collection = plan.collectionName {
                collectionID = store.workspace(id)?.collections.first { $0.name == collection }?.id
                    ?? store.addCollection(named: collection, to: id)
            }
            let before = Set(store.workspace(id)?.entries.map(\.path) ?? [])
            store.add(finalURLs, to: id, collection: collectionID)
            addedEntries = Set(store.workspace(id)?.entries.map(\.path) ?? []).subtracting(before)
            workspaceID = id
        }

        var summary: [String] = []
        if let name = plan.workspaceName {
            summary.append(String(localized: "\(addedEntries.count) files added to \(name)"))
        }
        if !renamed.isEmpty {
            summary.append(String(localized: "\(renamed.count) files renamed"))
        }
        let text = summary.isEmpty ? String(localized: "Nothing needed to change.") : summary.joined(separator: " · ")
        reply(text + ".")
        NoticeCenter.shared.show(text, symbolName: "sparkles", actionTitle: String(localized: "Undo")) { [weak self] in
            self?.undo(renamed: renamed, workspaceID: workspaceID, entries: addedEntries)
        }
    }

    private func undo(renamed: [(from: URL, to: URL)], workspaceID: UUID?, entries: Set<String>) {
        let store = WorkspaceStore.shared
        if let workspaceID, let workspace = store.workspace(workspaceID) {
            let ids = Set(workspace.entries.filter { entries.contains($0.path) }.map(\.id))
            store.remove(ids, from: workspaceID)
        }
        var restored: [URL: URL] = [:]
        for (from, to) in renamed where (try? FileManager.default.moveItem(at: to, to: from)) != nil {
            restored[to] = from
        }
        files = files.map { file in
            restored[file.url].map { AssistantFile(url: $0) } ?? file
        }
        reply(String(localized: "Undone: everything is back as it was."))
    }

    // MARK: - Other requests

    private func summarize(_ url: URL) {
        work?.cancel()
        isWorking = true
        files = [AssistantFile(url: url)]
        targetWorkspace = nil
        resultsTitle = url.lastPathComponent
        resultsSubtitle = AssistantFile(url: url).place
        work = Task { [weak self] in
            let summary = await LocalIntelligence.summary(of: url)
            guard let self, !Task.isCancelled else { return }
            self.isWorking = false
            if let summary {
                self.reply(String(localized: "Summary of “\(url.lastPathComponent)”:") + "\n" + summary)
            } else {
                self.reply(String(localized: "I could not read any text in “\(url.lastPathComponent)”."))
            }
        }
    }

    private func suggestFreeingSpace() {
        let analyzer = SpaceAnalyzer.shared
        if analyzer.lastScan != nil, analyzer.reclaimableBytes > 0 {
            reply(
                String(localized: "About **\(analyzer.reclaimableBytes.formattedByteCount)** can be freed: big files you no longer open, developer caches, duplicates and installers of apps already installed."),
                actions: [.openFreeUpSpace]
            )
        } else {
            reply(
                String(localized: "Free Up Space looks for big files you no longer open, developer caches, duplicates and installers of apps already installed. Nothing is deleted without your agreement."),
                actions: [.openFreeUpSpace]
            )
        }
    }

    // MARK: - Helpers

    private func reply(_ text: String, actions: [AssistantAction] = []) {
        messages.append(AssistantMessage(role: .assistant, text: Self.markdown(text), actions: actions))
    }

    private func settleOpenMessages() {
        for index in messages.indices where !messages[index].actions.isEmpty {
            messages[index].isSettled = true
        }
        plan = nil
    }

    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private static var folderList: String {
        String(localized: "Downloads, Documents and Desktop")
    }

    nonisolated private static func canSummarize(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .pdf) || type.conforms(to: .text)
    }
}

extension AssistantTopic {
    /// “factures”, as in “I found no factures”.
    var pluralTitle: String {
        switch self {
        case .invoices: String(localized: "invoices")
        case .receipts: String(localized: "receipts")
        case .quotes: String(localized: "quotes")
        case .contracts: String(localized: "contracts")
        case .payslips: String(localized: "payslips")
        case .statements: String(localized: "statements")
        case .taxes: String(localized: "tax documents")
        case .screenshots: String(localized: "screenshots")
        case .photos: String(localized: "photos")
        case .videos: String(localized: "videos")
        }
    }

    /// The name of the collection the files go to.
    var collectionTitle: String {
        switch self {
        case .invoices: String(localized: "Invoices")
        case .receipts: String(localized: "Receipts")
        case .quotes: String(localized: "Quotes")
        case .contracts: String(localized: "Contracts")
        case .payslips: String(localized: "Payslips")
        case .statements: String(localized: "Statements")
        case .taxes: String(localized: "Taxes")
        case .screenshots: String(localized: "Screenshots")
        case .photos: String(localized: "Photos")
        case .videos: String(localized: "Videos")
        }
    }

    /// The first word of a proposed name, such as “Facture”.
    var singularTitle: String {
        switch self {
        case .invoices: String(localized: "Invoice")
        case .receipts: String(localized: "Receipt")
        case .quotes: String(localized: "Quote")
        case .contracts: String(localized: "Contract")
        case .payslips: String(localized: "Payslip")
        case .statements: String(localized: "Statement")
        case .taxes: String(localized: "Tax notice")
        case .screenshots: String(localized: "Screenshot")
        case .photos: String(localized: "Photo")
        case .videos: String(localized: "Video")
        }
    }

    var example: String {
        switch self {
        case .invoices: String(localized: "Invoice EDF October 2026")
        case .screenshots: String(localized: "Screenshot – Flight booking Paris Tokyo")
        default: singularTitle + " " + String(localized: "Company Name March 2026")
        }
    }

    /// “14 invoices”, for sentences.
    func foundPhrase(_ count: Int) -> String {
        switch self {
        case .invoices: String(localized: "\(count) invoices")
        case .receipts: String(localized: "\(count) receipts")
        case .quotes: String(localized: "\(count) quotes")
        case .contracts: String(localized: "\(count) contracts")
        case .payslips: String(localized: "\(count) payslips")
        case .statements: String(localized: "\(count) statements")
        case .taxes: String(localized: "\(count) tax documents")
        case .screenshots: String(localized: "\(count) screenshots")
        case .photos: String(localized: "\(count) photos")
        case .videos: String(localized: "\(count) videos")
        }
    }

    /// “14 invoices found”, for the title of the results.
    func foundTitle(_ count: Int) -> String {
        switch self {
        case .invoices: String(localized: "\(count) invoices found")
        case .receipts: String(localized: "\(count) receipts found")
        case .quotes: String(localized: "\(count) quotes found")
        case .contracts: String(localized: "\(count) contracts found")
        case .payslips: String(localized: "\(count) payslips found")
        case .statements: String(localized: "\(count) statements found")
        case .taxes: String(localized: "\(count) tax documents found")
        case .screenshots: String(localized: "\(count) screenshots found")
        case .photos: String(localized: "\(count) photos found")
        case .videos: String(localized: "\(count) videos found")
        }
    }
}
