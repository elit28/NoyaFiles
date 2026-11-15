import SwiftUI

/// The clickable path of the current folder, such as "Macintosh HD › Users › noya › Downloads".
struct PathBar: View {
    let model: BrowserModel

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    let crumbs = PathCrumb.crumbs(for: model.location.url)
                    ForEach(Array(crumbs.enumerated()), id: \.element.url) { index, crumb in
                        if index > 0 {
                            separator
                        }
                        let isCurrent = index == crumbs.count - 1 && model.location.scope == .everything
                        Button {
                            model.navigate(to: crumb.url)
                        } label: {
                            Text(crumb.title)
                                .fontWeight(isCurrent ? .semibold : .regular)
                                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if let scopeTitle = model.location.scope.title {
                        separator
                        ScopeChip(
                            title: scopeTitle,
                            symbolName: model.location.scope.symbolName
                        ) {
                            model.show(.everything)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.never)

            Button {
                model.isGoToFolderPresented = true
            } label: {
                Text("⇧⌘G to go to a folder")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.trailing, 12)
            .help("Go to Folder…")
        }
        .font(.callout)
        .lineLimit(1)
        .frame(height: 30)
    }

    private var separator: some View {
        Image(systemName: "chevron.compact.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

/// Shows that the folder is narrowed to some of its files, with a button to show everything again.
private struct ScopeChip: View {
    let title: String
    let symbolName: String
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
            Text(title)
                .fontWeight(.semibold)
            Button(action: clear) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Show everything")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
    }
}

struct PathCrumb: Hashable {
    let url: URL
    let title: String

    /// The folders leading to `url`, starting at the root of its volume.
    static func crumbs(for url: URL) -> [PathCrumb] {
        let fileManager = FileManager.default
        let components = url.standardizedFileURL.pathComponents

        var current: URL
        var remaining: ArraySlice<String>
        if components.count >= 3, components[1] == "Volumes" {
            current = URL(fileURLWithPath: "/Volumes/\(components[2])", isDirectory: true)
            remaining = components.dropFirst(3)
        } else {
            current = URL(fileURLWithPath: "/", isDirectory: true)
            remaining = components.dropFirst(1)
        }

        var crumbs = [PathCrumb(url: current, title: fileManager.displayName(atPath: current.path))]
        for component in remaining {
            current = current.appendingPathComponent(component, isDirectory: true)
            crumbs.append(PathCrumb(url: current, title: fileManager.displayName(atPath: current.path)))
        }
        return crumbs
    }
}
