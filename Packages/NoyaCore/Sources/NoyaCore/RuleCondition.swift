import Foundation

/// What a file must look like for a smart rule to pick it up.
public enum RuleCondition: Codable, Hashable, Sendable {
    /// The name contains some text, ignoring case and accents, optionally limited to some extensions.
    case nameContains(String, extensions: [String])
    /// The file carries a Finder tag, ignoring case.
    case tagged(String)
    /// The file belongs to a category, such as PDFs.
    case category(FileCategory)

    /// Whether a file matches. Folders never match.
    ///
    /// - Parameter tags: The file's Finder tags.
    public func matches(_ item: FileItem, tags: [String] = []) -> Bool {
        guard !item.isFolder else { return false }
        switch self {
        case .nameContains(let text, let extensions):
            let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { return false }
            let allowed = extensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) }
            if !allowed.isEmpty, !allowed.contains(item.fileExtension) { return false }
            return item.name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        case .tagged(let tag):
            let wanted = tag.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).lowercased()
            return !wanted.isEmpty && tags.contains { $0.lowercased() == wanted }
        case .category(let category):
            return item.category == category
        }
    }
}
