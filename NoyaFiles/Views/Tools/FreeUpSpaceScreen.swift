import AppKit
import NoyaCore
import SwiftUI

/// Finds big files, caches, duplicates and old installers, and frees the space they take.
struct FreeUpSpaceScreen: View {
    @Bindable private var analyzer = SpaceAnalyzer.shared
    @State private var isConfirmingTrash = false
    @State private var isConfirmingEmptyTrash = false
    @State private var isConfirmingDuplicates = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    diskBar
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14, alignment: .top)], spacing: 14) {
                        candidatesCard(
                            title: "Large Files",
                            symbol: "doc.zipper",
                            candidates: analyzer.largeFiles,
                            empty: "No file over 500 MB in your home folder."
                        )
                        candidatesCard(
                            title: "Developer Caches",
                            symbol: "hammer",
                            candidates: analyzer.developerCaches,
                            empty: "No developer cache worth cleaning."
                        )
                        duplicatesCard
                        candidatesCard(
                            title: "Installers Already Installed",
                            symbol: "shippingbox",
                            candidates: analyzer.installers,
                            empty: "No leftover installer in Downloads."
                        )
                        trashCard
                    }
                }
                .padding(24)
            }
            Divider()
            footer
        }
        .navigationTitle("Free Up Space")
        .toolbar {
            ToolbarItem {
                Button {
                    analyzer.scan()
                } label: {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                }
                .disabled(analyzer.isScanning)
                .help("Scan the disk again")
            }
        }
        .onAppear { analyzer.scanIfNeeded() }
        .confirmationDialog(
            String(localized: "Move \(analyzer.selection.count) items to the Trash?"),
            isPresented: $isConfirmingTrash,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                let count = analyzer.trashSelection()
                NoticeCenter.shared.show(String(localized: "\(count) items moved to the Trash"), symbolName: "trash")
            }
        } message: {
            Text("You can still recover them from the Trash until you empty it.")
        }
        .confirmationDialog("Empty the Trash?", isPresented: $isConfirmingEmptyTrash, titleVisibility: .visible) {
            Button("Empty Trash", role: .destructive) { analyzer.emptyTrash() }
        } message: {
            Text("The items in the Trash will be deleted for good. This cannot be undone.")
        }
        .confirmationDialog("Keep only the most recent copy of each duplicate?", isPresented: $isConfirmingDuplicates, titleVisibility: .visible) {
            Button("Move Copies to Trash", role: .destructive) {
                let count = analyzer.trashDuplicates()
                NoticeCenter.shared.show(String(localized: "\(count) items moved to the Trash"), symbolName: "trash")
            }
        }
    }

    // MARK: - Header and disk

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Free Up Space")
                .font(.largeTitle.weight(.bold))
            HStack(spacing: 8) {
                if analyzer.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning your Mac… Results appear as they are found.")
                } else if let lastScan = analyzer.lastScan {
                    let when = lastScan.formatted(.relative(presentation: .named))
                    let freeable = analyzer.reclaimableBytes.formattedByteCount
                    Text("Scanned \(when) · \(freeable) can be freed")
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var diskBar: some View {
        if let disk = analyzer.disk {
            let used = Double(disk.totalBytes - disk.availableBytes)
            let total = Double(max(disk.totalBytes, 1))
            let known = analyzer.slices.reduce(Int64(0)) { $0 + $1.bytes }
            let system = max(0, Int64(used) - known)
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        ForEach(analyzer.slices) { slice in
                            Rectangle()
                                .fill(slice.tint.tint)
                                .frame(width: proxy.size.width * Double(slice.bytes) / total)
                        }
                        Rectangle()
                            .fill(Color.secondary.opacity(0.6))
                            .frame(width: proxy.size.width * Double(analyzer.slices.isEmpty ? Int64(used) : system) / total)
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 14)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
                .accessibilityElement()
                .accessibilityLabel(Text("\(disk.availableBytes.formattedByteCount) available of \(disk.totalBytes.formattedByteCount)"))

                FlowRow(spacing: 16) {
                    ForEach(analyzer.slices) { slice in
                        legend(slice.title, slice.bytes, color: slice.tint.tint)
                    }
                    if !analyzer.slices.isEmpty {
                        legend(String(localized: "System and other"), system, color: .secondary.opacity(0.6))
                    }
                    legend(String(localized: "Available"), disk.availableBytes, color: Color.primary.opacity(0.12))
                }
                .font(.callout)
            }
        }
    }

    private func legend(_ title: String, _ bytes: Int64, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
            Text(bytes.formattedByteCount)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Cards

    private func candidatesCard(title: LocalizedStringKey, symbol: String, candidates: [SpaceCandidate], empty: LocalizedStringKey) -> some View {
        Card(title: title, symbol: symbol, total: candidates.reduce(Int64(0)) { $0 + $1.bytes }) {
            if candidates.isEmpty {
                if analyzer.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(empty)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(candidates.prefix(6)) { candidate in
                    Toggle(isOn: selectionBinding(for: candidate.url)) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(candidate.title)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(candidate.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(candidate.bytes.formattedByteCount)
                                .monospacedDigit()
                        }
                    }
                    .toggleStyle(.checkbox)
                    .contextMenu {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([candidate.url]) }
                    }
                }
                if candidates.count > 6 {
                    Text(String(localized: "and \(candidates.count - 6) more"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var duplicatesCard: some View {
        Card(title: "Duplicates", symbol: "doc.on.doc", total: DuplicateFinder.reclaimableBytes(in: analyzer.duplicateGroups)) {
            if analyzer.duplicateGroups.isEmpty {
                if analyzer.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("No duplicates in Downloads, Desktop or Documents.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(analyzer.duplicateGroups.prefix(4), id: \.first?.url) { group in
                    HStack {
                        Text(group[0].name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(verbatim: "× \(group.count)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(group[0].size.formattedByteCount)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Button("Keep the Most Recent of Each…") { isConfirmingDuplicates = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    private var trashCard: some View {
        Card(title: "Trash", symbol: "trash", total: analyzer.trashBytes ?? 0) {
            if !analyzer.canReadTrash {
                Text("NOYA Files needs Full Disk Access to look inside the Trash.")
                    .foregroundStyle(.secondary)
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(PrivacyStatus.fullDiskAccessSettingsURL)
                }
            } else if analyzer.trashCount == 0 {
                Text(analyzer.isScanning ? LocalizedStringKey("Measuring…") : LocalizedStringKey("The Trash is empty."))
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "\(analyzer.trashCount) items in the Trash"))
                    .foregroundStyle(.secondary)
                Button("Empty Trash…") { isConfirmingEmptyTrash = true }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Selection: \(analyzer.selection.count) items · \(analyzer.selectedBytes.formattedByteCount)"))
                    .fontWeight(.semibold)
                Text("Everything goes to the Trash: nothing is deleted for good.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Move to Trash…") { isConfirmingTrash = true }
                .buttonStyle(.borderedProminent)
                .disabled(analyzer.selection.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func selectionBinding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { analyzer.selection.contains(url) },
            set: { isOn in
                if isOn {
                    analyzer.selection.insert(url)
                } else {
                    analyzer.selection.remove(url)
                }
            }
        )
    }
}

/// A titled box with a total, used for each kind of space to free.
private struct Card<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    let total: Int64
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline)
                Spacer()
                if total > 0 {
                    Text(total.formattedByteCount)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        }
    }
}
