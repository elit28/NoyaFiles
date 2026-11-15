import NoyaCore
import SwiftUI

/// Two folders side by side, to copy and move files between them.
struct DualPaneScreen: View {
    @Bindable var window: WindowModel

    var body: some View {
        if let secondary = window.secondary {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    PaneView(
                        model: window.browser,
                        badge: String(localized: "L"),
                        isActive: window.activePane == .primary,
                        activate: { window.activePane = .primary },
                        drop: { urls in window.drop(urls, into: window.browser.location.url) }
                    )
                    Divider()
                    PaneView(
                        model: secondary,
                        badge: String(localized: "R"),
                        isActive: window.activePane == .secondary,
                        activate: { window.activePane = .secondary },
                        drop: { urls in window.drop(urls, into: secondary.location.url) }
                    )
                }
                Divider()
                actionBar(target: window.inactiveBrowser)
            }
            .navigationTitle("Dual Pane")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ControlGroup {
                        Button {
                            window.activeBrowser.goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .disabled(!window.activeBrowser.canGoBack)
                        Button {
                            window.activeBrowser.goForward()
                        } label: {
                            Label("Forward", systemImage: "chevron.right")
                        }
                        .disabled(!window.activeBrowser.canGoForward)
                    }
                    .controlGroupStyle(.navigation)
                }
                ToolbarItem {
                    Button {
                        window.swapPanes()
                    } label: {
                        Label("Swap Panes", systemImage: "arrow.left.arrow.right")
                    }
                    .help("Swap the two folders")
                }
                ToolbarItem {
                    Toggle(isOn: $window.isComparing) {
                        Label("Compare Folders", systemImage: "rectangle.2.swap")
                    }
                    .help("Highlight items that exist in only one folder")
                }
                ToolbarItem {
                    Toggle(isOn: $window.isDualPane) {
                        Label("Dual Pane", systemImage: "rectangle.split.2x1")
                    }
                    .help("Back to a single folder")
                }
            }
            .onChange(of: window.browser.items) { window.updateComparison() }
            .onChange(of: secondary.items) { window.updateComparison() }
            .onChange(of: window.browser.selection) {
                if !window.browser.selection.isEmpty { window.activePane = .primary }
            }
            .onChange(of: secondary.selection) {
                if !secondary.selection.isEmpty { window.activePane = .secondary }
            }
        }
    }

    private func actionBar(target: BrowserModel?) -> some View {
        let source = window.activeBrowser
        let count = source.selectedItems.count
        let pointsRight = window.activePane == .primary
        let targetTitle = target?.title ?? ""

        return HStack(spacing: 10) {
            Text(count > 0 ? String(localized: "\(count) selected in \(source.title)") : String(localized: "Select items to copy or move them."))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button {
                window.transferSelection(.copy)
            } label: {
                Label(
                    String(localized: "Copy to \(targetTitle)"),
                    systemImage: pointsRight ? "arrow.right" : "arrow.left"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(count == 0 || window.operations.current != nil)
            Button("Move") { window.transferSelection(.move) }
                .disabled(count == 0 || window.operations.current != nil)
            Text("F5 copy · F6 move · ⌃Tab other pane")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// One side of the dual pane.
private struct PaneView: View {
    let model: BrowserModel
    let badge: String
    let isActive: Bool
    let activate: () -> Void
    let drop: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(badge)
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .foregroundStyle(isActive ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
                    .background(
                        isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                Text(model.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Text(String(localized: "\(model.visibleItemCount) items"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(alignment: .top) {
                if isActive {
                    Rectangle()
                        .fill(.tint)
                        .frame(height: 3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: activate)

            Divider()

            Group {
                switch model.loadState {
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                case .failed(let error):
                    FolderErrorView(error: error) { model.reload() }
                case .loaded:
                    if model.rootNodes.isEmpty {
                        ContentUnavailableView("This folder is empty", systemImage: "folder")
                    } else {
                        FileListView(model: model)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .dropDestination(for: URL.self) { urls, _ in
            drop(urls)
            return true
        }
    }
}

/// A copy or move in progress, in the corner of the window.
struct OperationToast: View {
    let operation: FileOperation
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
                Text(operation.fraction, format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            UsageBar(fraction: operation.fraction, fill: .tint)
            HStack {
                Text(operation.currentName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Cancel", action: cancel)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .padding(18)
    }

    private var title: String {
        switch operation.kind {
        case .copy: String(localized: "Copying \(operation.totalCount) items to \(operation.destinationName)")
        case .move: String(localized: "Moving \(operation.totalCount) items to \(operation.destinationName)")
        }
    }
}
