import Foundation

/// What to look for, independent of where.
public struct SearchCriteria: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case folders, documents, pdfs, images, videos, audio, archives, installers, code, mail
    }

    public enum Period: String, Codable, CaseIterable, Sendable {
        case any, today, week, month, year
    }

    public var text: String
    /// Whether the text may also match inside files, not only in their names.
    public var searchesContents: Bool
    public var kinds: Set<Kind>
    public var period: Period
    /// Smallest size in bytes, or zero for any size.
    public var minimumSize: Int64
    public var tags: Set<String>

    public init(
        text: String = "",
        searchesContents: Bool = true,
        kinds: Set<Kind> = [],
        period: Period = .any,
        minimumSize: Int64 = 0,
        tags: Set<String> = []
    ) {
        self.text = text
        self.searchesContents = searchesContents
        self.kinds = kinds
        self.period = period
        self.minimumSize = minimumSize
        self.tags = tags
    }

    /// Whether the criteria narrow anything down. Searching with none would list the whole Mac.
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && kinds.isEmpty && tags.isEmpty
    }

    /// The criteria as a Spotlight query string, or `nil` when they are empty.
    public var spotlightQuery: String? {
        guard !isEmpty else { return nil }
        var clauses: [String] = []

        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        for word in words {
            let pattern = "\"*\(Self.escape(word))*\"cd"
            if searchesContents {
                clauses.append("(kMDItemFSName == \(pattern) || kMDItemTextContent == \(pattern))")
            } else {
                clauses.append("kMDItemFSName == \(pattern)")
            }
        }

        if !kinds.isEmpty {
            let types = kinds.sorted { $0.rawValue < $1.rawValue }.flatMap(\.contentTypes)
            clauses.append("(" + types.map { "kMDItemContentTypeTree == \"\($0)\"" }.joined(separator: " || ") + ")")
        }

        switch period {
        case .any: break
        case .today: clauses.append("kMDItemFSContentChangeDate >= $time.today")
        case .week: clauses.append("kMDItemFSContentChangeDate >= $time.today(-7)")
        case .month: clauses.append("kMDItemFSContentChangeDate >= $time.today(-30)")
        case .year: clauses.append("kMDItemFSContentChangeDate >= $time.this_year")
        }

        if minimumSize > 0 {
            clauses.append("kMDItemFSSize >= \(minimumSize)")
        }

        for tag in tags.sorted() {
            clauses.append("kMDItemUserTags == \"\(Self.escape(tag))\"cd")
        }

        return clauses.joined(separator: " && ")
    }

    /// Escapes the characters that have a meaning in Spotlight query strings.
    static func escape(_ text: String) -> String {
        var escaped = ""
        for character in text {
            if character == "\\" || character == "\"" || character == "*" || character == "?" {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }
}

extension SearchCriteria.Kind {
    /// The Uniform Type Identifiers Spotlight files this kind under.
    public var contentTypes: [String] {
        switch self {
        case .folders: ["public.folder"]
        case .documents: ["public.composite-content", "public.plain-text", "public.rtf", "public.spreadsheet", "public.presentation"]
        case .pdfs: ["com.adobe.pdf"]
        case .images: ["public.image"]
        case .videos: ["public.movie"]
        case .audio: ["public.audio"]
        case .archives: ["public.archive"]
        case .installers: ["com.apple.disk-image", "com.apple.installer-package-archive"]
        case .code: ["public.source-code"]
        case .mail: ["com.apple.mail.emlx"]
        }
    }
}

/// A short excerpt of text around the first occurrence of a word, such as “… the invoice n° 118 …”.
public enum SnippetMaker {
    public static func snippet(around word: String, in text: String, radius: Int = 40) -> String? {
        guard !word.isEmpty,
              let range = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive])
        else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        let excerpt = text[start..<end]
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        let prefix = start > text.startIndex ? "… " : ""
        let suffix = end < text.endIndex ? " …" : ""
        return prefix + excerpt + suffix
    }
}
