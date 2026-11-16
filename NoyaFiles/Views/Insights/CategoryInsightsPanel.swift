import NoyaCore
import SwiftUI

/// Insights about one category of files in a folder: formats and duplicates.
struct CategoryInsightsPanel: View {
    let model: BrowserModel
    let category: FileCategory

    var body: some View {
        let items = model.shownItems
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        let formats = Grouping.byFormat(items)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(category.title) in \(model.title)")
                        .font(.headline)
                        .lineLimit(2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(total.formattedByteCount)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("in all")
                            .foregroundStyle(.secondary)
                    }
                    Text(String(localized: "\(items.count) files"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("By Format")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(formats.prefix(6)) { format in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(format.format.isEmpty ? String(localized: "No extension") : format.format)
                                Text(String(localized: "\(format.count) files"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(format.bytes.formattedByteCount)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                            UsageBar(
                                fraction: total > 0 ? Double(format.bytes) / Double(total) : 0,
                                fill: category.tint
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggestions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    duplicates
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var duplicates: some View {
        if model.isFindingDuplicates {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Looking for duplicates…")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        } else if model.duplicateGroups.isEmpty {
            Text("No duplicates here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            let extras = DuplicateFinder.extraCopies(in: model.duplicateGroups)
            let bytes = DuplicateFinder.reclaimableBytes(in: model.duplicateGroups)
            let example = model.duplicateGroups[0]
            VStack(alignment: .leading, spacing: 8) {
                Text([String(localized: "\(extras.count) duplicates"), bytes.formattedByteCount].joined(separator: " · "))
                    .font(.callout.weight(.semibold))
                Text("Same contents, different names, such as “\(example[0].name)” and “\(example[1].name)”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Compare…") { model.isDuplicatesSheetPresented = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
    }
}

/// Lists identical files side by side, and offers to keep only the most recent copy.
struct DuplicatesSheet: View {
    let model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let groups = model.duplicateGroups
        let extras = Set(DuplicateFinder.extraCopies(in: groups).map(\.url))

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicates")
                    .font(.title3.weight(.semibold))
                Text("Files with exactly the same contents. The most recent copy of each is kept.")
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            List {
                ForEach(groups.indices, id: \.self) { index in
                    Section {
                        ForEach(groups[index]) { item in
                            HStack(spacing: 10) {
                                FileThumbnail(item: item, side: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    Text(DateText.string(for: item.lastActivityDate ?? .distantPast))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if extras.contains(item.url) {
                                    Text("Moves to the Trash")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Label("Kept", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    } header: {
                        Text(groups[index][0].size.formattedByteCount)
                    }
                }
            }
            .frame(minHeight: 280)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Keep the Most Recent") {
                    dismiss()
                    model.requestTrashingDuplicates()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(extras.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 560, height: 520)
    }
}
