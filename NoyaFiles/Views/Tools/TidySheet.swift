import AppKit
import NoyaCore
import SwiftUI

/// Previews how the Downloads folder would be tidied up, and does it on confirmation.
struct TidySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var tidy = TidyController.shared
    @State private var plan: TidyPlan?
    @State private var isWorking = false
    @State private var showsDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            HStack(alignment: .top, spacing: 0) {
                rulesList
                    .frame(minWidth: 430, maxWidth: .infinity, alignment: .topLeading)
                Divider()
                summary
                    .frame(width: 290, alignment: .topLeading)
            }
            if showsDetails, let plan {
                Divider()
                details(plan)
            }
            Divider()
            footer
        }
        .frame(width: 780)
        .task(id: tidy.rules) {
            plan = await tidy.makePlan()
        }
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "tray.and.arrow.down")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Tidy Up Downloads")
                    .font(.title3.weight(.semibold))
                Text(introduction)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
    }

    private var introduction: String {
        guard let plan else { return String(localized: "Looking at your Downloads folder…") }
        let total = plan.moves.count + plan.remainingCount
        return String(localized: "NOYA Files suggests putting away \(plan.moves.count) of \(total) loose files. Nothing moves until you confirm, and you can undo it afterwards.")
    }

    private var rulesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rules")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(tidy.rules) { rule in
                RuleRow(rule: rule, plan: plan)
            }
        }
        .padding(20)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("After Tidying")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if let plan {
                LabeledContent(String(localized: "Downloads")) {
                    Text(String(localized: "\(plan.remainingCount) items left"))
                        .foregroundStyle(.secondary)
                }
                ForEach(tidy.rules.filter(\.isEnabled)) { rule in
                    let count = plan.moves(for: rule.kind).count
                    if count > 0 {
                        LabeledContent(rule.destination.map(Self.shortPath) ?? String(localized: "Trash")) {
                            Text(verbatim: "+\(count)")
                                .fontWeight(.semibold)
                                .foregroundStyle(rule.destination == nil ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
                        }
                        .font(.callout)
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Divider()
            Toggle("Tidy up automatically every week", isOn: $tidy.tidiesWeekly)
            Toggle("Show this preview each time", isOn: $tidy.showsPreview)
                .disabled(!tidy.tidiesWeekly)
        }
        .padding(20)
        .background(Color.primary.opacity(0.03))
    }

    private func details(_ plan: TidyPlan) -> some View {
        List(plan.moves, id: \.item.url) { move in
            HStack {
                Text(move.item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                Text(move.destination.map(Self.shortPath) ?? String(localized: "Trash"))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.callout)
        }
        .frame(height: 200)
    }

    private var footer: some View {
        HStack {
            Button(showsDetails ? LocalizedStringKey("Hide Details") : LocalizedStringKey("Detailed Preview…")) {
                showsDetails.toggle()
            }
            .disabled(plan?.moves.isEmpty ?? true)
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(String(localized: "Tidy Up \(plan?.moves.count ?? 0) Files")) {
                guard let plan else { return }
                isWorking = true
                Task {
                    let outcome = await tidy.apply(plan)
                    isWorking = false
                    dismiss()
                    TidySheet.announce(outcome)
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isWorking || (plan?.moves.isEmpty ?? true))
        }
        .padding(16)
    }

    /// Tells the user what happened, with a way to undo it.
    static func announce(_ outcome: TidyOutcome) {
        let notices = NoticeCenter.shared
        let moved = outcome.records.count
        guard moved > 0 else { return }
        notices.show(
            String(localized: "Tidy-up done: \(moved) files put away"),
            symbolName: "checkmark.circle",
            actionTitle: String(localized: "Undo")
        ) {
            Task {
                await TidyController.shared.undoLastRun()
                NoticeCenter.shared.show(String(localized: "Files put back where they were"), symbolName: "arrow.uturn.backward")
            }
        }
    }

    /// A folder as a short path, such as “Pictures › Downloaded”.
    static func shortPath(_ url: URL) -> String {
        SearchScreen.folderTitle(url)
    }
}

private struct RuleRow: View {
    let rule: TidyRule
    let plan: TidyPlan?
    @Bindable private var tidy = TidyController.shared

    var body: some View {
        let moves = plan?.moves(for: rule.kind) ?? []
        HStack(alignment: .top, spacing: 12) {
            Toggle(isOn: Binding(
                get: { rule.isEnabled },
                set: { tidy.setRule(rule.kind, enabled: $0) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel(rule.kind.title)
            Circle()
                .fill(rule.kind.tint.tint)
                .frame(width: 9, height: 9)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(rule.kind.title)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if let destination = rule.destination {
                        Button(TidySheet.shortPath(destination)) { chooseDestination() }
                            .buttonStyle(.link)
                            .help("Choose another folder")
                    } else {
                        Text("Trash")
                            .foregroundStyle(.orange)
                    }
                }
                if rule.kind == .installedInstallers, !moves.isEmpty {
                    Text(installedApps(moves))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if rule.isEnabled {
                Text([String(localized: "\(moves.count) files"), moves.reduce(Int64(0)) { $0 + $1.item.size }.formattedByteCount].joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(rule.isEnabled ? 0.15 : 0.08), style: StrokeStyle(lineWidth: 1, dash: rule.isEnabled ? [] : [4]))
        )
        .opacity(rule.isEnabled ? 1 : 0.7)
    }

    private func installedApps(_ moves: [TidyMove]) -> String {
        let names = moves.compactMap { move in
            InstalledAppMatcher.installedApp(forInstaller: move.item.name, among: InstalledAppMatcher.installedAppNames())
        }
        let list = names.formatted(.list(type: .and))
        return String(localized: "Already in Applications: \(list).")
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = rule.destination
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        tidy.setDestination(url, for: rule.kind)
    }
}
