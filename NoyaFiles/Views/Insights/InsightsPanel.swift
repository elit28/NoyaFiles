import NoyaCore
import SwiftUI

/// The right-hand panel: how much space the folder takes, what takes it, and what could go.
struct InsightsPanel: View {
    @Bindable var model: BrowserModel
    @Environment(\.tidyUp) private var tidyUp

    private let maxEntries = 6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                breakdown
                hiddenItems
                suggestions
                if model.isDownloadsFolder {
                    Button {
                        tidyUp()
                    } label: {
                        Label("Tidy Up Downloads…", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var insights: FolderInsights { model.insights }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.headline)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(insights.totalBytes.formattedByteCount)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("in all")
                    .foregroundStyle(.secondary)
                if model.isMeasuring {
                    ProgressView()
                        .controlSize(.small)
                        .help("Calculating sizes…")
                }
            }
            Text(summaryLine)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryLine: String {
        [
            String(localized: "\(insights.folderCount) folders"),
            String(localized: "\(insights.looseFileCount) loose files"),
        ].joined(separator: " · ")
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelSectionTitle("What Takes the Space")
            if insights.entries.isEmpty {
                Text("Nothing here yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(insights.entries.prefix(maxEntries)) { entry in
                Button {
                    open(entry)
                } label: {
                    BreakdownRow(entry: entry, totalBytes: insights.totalBytes)
                }
                .buttonStyle(.plain)
            }
            if insights.entries.count > maxEntries {
                Text("and \(insights.entries.count - maxEntries) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hiddenItems: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
                .foregroundStyle(.secondary)
            Text("Hidden items")
            Spacer()
            Text(insights.hiddenBytes.formattedByteCount)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Toggle("Show hidden items", isOn: $model.showHidden)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .font(.callout)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelSectionTitle("Suggestions")
            let visible = model.visibleSuggestions
            if visible.isEmpty {
                Text("Nothing to clean up here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(visible) { suggestion in
                SuggestionCard(
                    suggestion: suggestion,
                    review: { model.review(suggestion) },
                    trashInstalled: { model.requestTrashingInstalled(from: suggestion) },
                    dismiss: { model.dismiss(suggestion) }
                )
            }
        }
    }

    private func open(_ entry: FolderInsights.Entry) {
        switch entry.subject {
        case .folder(let url, _):
            model.navigate(to: url)
        case .category(let category):
            model.show(.category(category))
        }
    }
}

struct PanelSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct BreakdownRow: View {
    let entry: FolderInsights.Entry
    let totalBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                indicator
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text(entry.bytes.formattedByteCount)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            UsageBar(
                fraction: totalBytes > 0 ? Double(entry.bytes) / Double(totalBytes) : 0,
                fill: tint
            )
        }
        .contentShape(Rectangle())
    }

    private var title: String {
        switch entry.subject {
        case .folder(_, let name): name
        case .category(let category): category.title
        }
    }

    private var tint: AnyShapeStyle {
        switch entry.subject {
        case .folder: AnyShapeStyle(.tint)
        case .category(let category): AnyShapeStyle(category.tint)
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch entry.subject {
        case .folder:
            Image(systemName: "folder.fill")
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 12)
        case .category:
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .frame(width: 12)
        }
    }
}

private struct SuggestionCard: View {
    let suggestion: CleanupSuggestion
    let review: () -> Void
    let trashInstalled: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Dismiss")
            }
            HStack(spacing: 12) {
                if !suggestion.installedMatches.isEmpty {
                    Button("Move to Trash…", action: trashInstalled)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                Button("Review", action: review)
                    .buttonStyle(.link)
            }
            .padding(.leading, 24)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private var symbolName: String {
        switch suggestion.kind {
        case .installers: "shippingbox"
        case .staleFiles: "clock"
        }
    }

    private var title: String {
        switch suggestion.kind {
        case .installers:
            [String(localized: "\(suggestion.count) installers"), suggestion.bytes.formattedByteCount]
                .joined(separator: " · ")
        case .staleFiles:
            [String(localized: "\(suggestion.count) old files"), suggestion.bytes.formattedByteCount]
                .joined(separator: " · ")
        }
    }

    private var subtitle: String {
        switch suggestion.kind {
        case .installers:
            let names = suggestion.installedMatches.map(\.appName)
            guard !names.isEmpty else {
                return String(localized: "Disk images and packages you may no longer need.")
            }
            let shown = names.prefix(3).joined(separator: ", ") + (names.count > 3 ? "…" : "")
            return String(localized: "Already installed: \(shown).")
        case .staleFiles(let days):
            return String(localized: "Untouched for more than \(days) days. You may not need them anymore.")
        }
    }
}
