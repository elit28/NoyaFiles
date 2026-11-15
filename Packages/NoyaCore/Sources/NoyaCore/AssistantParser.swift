import Foundation

/// A kind of document or media the assistant knows how to look for.
public enum AssistantTopic: String, CaseIterable, Codable, Sendable {
    case invoices, receipts, quotes, contracts, payslips, statements, taxes, screenshots, photos, videos

    /// Words that name the topic in a request, in French and English, without accents.
    var triggers: [String] {
        switch self {
        case .invoices: ["facture", "factures", "invoice", "invoices", "bill", "bills"]
        case .receipts: ["recu", "recus", "ticket de caisse", "tickets de caisse", "receipt", "receipts"]
        case .quotes: ["devis", "quote", "quotes", "quotation", "quotations"]
        case .contracts: ["contrat", "contrats", "contract", "contracts"]
        case .payslips: ["fiche de paie", "fiches de paie", "bulletin de paie", "bulletins de paie",
                         "bulletin de salaire", "bulletins de salaire", "payslip", "payslips", "pay slip", "pay slips"]
        case .statements: ["releve", "releves", "statement", "statements"]
        case .taxes: ["impot", "impots", "avis d'imposition", "avis d'impot", "tax return", "tax returns", "taxes"]
        case .screenshots: ["capture d'ecran", "captures d'ecran", "capture", "captures", "screenshot", "screenshots"]
        case .photos: ["photo", "photos", "image", "images", "picture", "pictures"]
        case .videos: ["video", "videos", "film", "films", "movie", "movies"]
        }
    }

    /// Words looked for in file names and contents, with their accents.
    public var searchTerms: [String] {
        switch self {
        case .invoices: ["facture", "invoice"]
        case .receipts: ["reçu", "ticket de caisse", "receipt"]
        case .quotes: ["devis", "quotation"]
        case .contracts: ["contrat", "contract"]
        case .payslips: ["bulletin de paie", "bulletin de salaire", "fiche de paie", "payslip"]
        case .statements: ["relevé", "statement"]
        case .taxes: ["impôt", "avis d'imposition", "tax"]
        case .screenshots, .photos, .videos: []
        }
    }

    /// What kind of file the topic is about.
    public var kind: SearchCriteria.Kind {
        switch self {
        case .screenshots, .photos: .images
        case .videos: .videos
        default: .pdfs
        }
    }

    /// Whether the topic is about documents whose text can suggest a better name.
    public var isDocument: Bool { kind == .pdfs }
}

/// What a request typed to the assistant asks for.
public enum AssistantIntent: Equatable, Sendable {
    /// Find files, and add them to a workspace when one is named.
    case gather(AssistantRequest)
    /// Give clearer names to screenshots.
    case renameScreenshots
    /// Summarize a document.
    case summarize
    /// Say what can be deleted to free space.
    case freeUpSpace
    case unknown
}

/// A search the assistant runs, with what to do with the files it finds.
public struct AssistantRequest: Equatable, Sendable {
    public var topic: AssistantTopic?
    /// Words to look for when no topic matched, such as ["budget", "vacances"].
    public var keywords: [String]
    public var year: Int?
    /// The workspace named in the request, as written by the person.
    public var workspaceName: String?
    /// Whether the workspace already exists, as opposed to one to create.
    public var workspaceExists: Bool
    /// Whether files with unclear names should get a name taken from their contents.
    public var renames: Bool

    public init(
        topic: AssistantTopic? = nil,
        keywords: [String] = [],
        year: Int? = nil,
        workspaceName: String? = nil,
        workspaceExists: Bool = false,
        renames: Bool = true
    ) {
        self.topic = topic
        self.keywords = keywords
        self.year = year
        self.workspaceName = workspaceName
        self.workspaceExists = workspaceExists
        self.renames = renames
    }

    /// The Spotlight query finding the files, or `nil` when there is nothing to look for.
    ///
    /// The year is not part of it: Spotlight dates vary from one file type to another, so
    /// ``matchesYear(fileName:dates:)`` checks it on each file found.
    public var spotlightQuery: String? {
        var clauses: [String] = []
        if let topic {
            let terms = topic.searchTerms.map { "\"*\(SearchCriteria.escape($0))*\"cd" }
            if !terms.isEmpty {
                clauses.append("(" + terms.map { "kMDItemFSName == \($0) || kMDItemTextContent == \($0)" }.joined(separator: " || ") + ")")
            }
            if topic == .screenshots {
                clauses.append("kMDItemIsScreenCapture == 1")
            }
            clauses.append("(" + topic.kind.contentTypes.map { "kMDItemContentTypeTree == \"\($0)\"" }.joined(separator: " || ") + ")")
        } else if keywords.isEmpty {
            return nil
        }
        // Each extra word, such as a company name, must appear in the name or the contents.
        for word in keywords {
            let pattern = "\"*\(SearchCriteria.escape(word))*\"cd"
            clauses.append("(kMDItemFSName == \(pattern) || kMDItemTextContent == \(pattern))")
        }
        return clauses.joined(separator: " && ")
    }

    /// Whether a file belongs to the year asked for: its name mentions it, or one of its dates
    /// (created, modified, added) falls in it. Always true when no year was asked for.
    public func matchesYear(fileName: String, dates: [Date], calendar: Calendar = .current) -> Bool {
        guard let year else { return true }
        if fileName.contains(String(year)) { return true }
        return dates.contains { calendar.component(.year, from: $0) == year }
    }
}

/// Understands simple requests, in French or English, without any language model.
///
/// It recognizes what the person wants (find, rename, summarize, free space), the kind of
/// document, a year and a workspace. Anything else is left to the person to rephrase.
public enum AssistantParser {
    public static func parse(_ request: String, workspaces: [String] = [], now: Date = Date()) -> AssistantIntent {
        var text = request
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .unknown }

        // The workspace comes first: its name may hold words such as “Impôts” or “2026”.
        let workspace = extractWorkspace(from: &text, known: workspaces)
        let plain = normalize(text)
        let words = Set(plain.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init))

        func has(_ phrase: String) -> Bool {
            phrase.contains(" ") || phrase.contains("'") ? plain.contains(phrase) : words.contains(phrase)
        }

        if ["resume", "resumer", "resumes", "summarize", "summarise", "summary", "synthese"].contains(where: has) {
            return .summarize
        }
        let renames = ["renomme", "renommer", "rename"].contains(where: has)
        let topic = AssistantTopic.allCases.first { $0.triggers.contains(where: has) }
        if renames, topic == .screenshots {
            return .renameScreenshots
        }
        let freesSpace = ["supprimer", "effacer", "liberer", "nettoyer", "delete", "remove", "clean", "free"].contains(where: has)
            || plain.contains("de la place") || plain.contains("free up")
        if freesSpace, topic == nil, workspace == nil {
            return .freeUpSpace
        }

        let currentYear = Calendar(identifier: .gregorian).component(.year, from: now)
        var year = words.compactMap { word -> Int? in
            guard word.count == 4, let value = Int(word), (1990...2100).contains(value) else { return nil }
            return value
        }.first
        if year == nil {
            if ["cette annee", "this year"].contains(where: plain.contains) {
                year = currentYear
            } else if ["l'annee derniere", "annee derniere", "last year"].contains(where: plain.contains) {
                year = currentYear - 1
            }
        }
        let keepsNames = plain.contains("sans renommer") || plain.contains("without renaming") || plain.contains("don't rename")

        // The words left once the request, the topic and the dates are set aside, such as “EDF”.
        let topicWords = Set((topic?.triggers ?? []).flatMap { $0.split(separator: " ").map(String.init) })
        let keywords = text
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { word in
                let folded = normalize(word)
                return folded.count > 2 && !stopWords.contains(folded) && !topicWords.contains(folded) && Int(folded) == nil
            }
        guard topic != nil || !keywords.isEmpty else { return .unknown }

        return .gather(AssistantRequest(
            topic: topic,
            keywords: keywords,
            year: year,
            workspaceName: workspace?.name,
            workspaceExists: workspace?.exists ?? false,
            renames: !keepsNames
        ))
    }

    /// Lowercased, without accents, with straight apostrophes.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "’", with: "'")
    }

    /// Finds the workspace named in the request and removes it from the text.
    private static func extractWorkspace(from text: inout String, known: [String]) -> (name: String, exists: Bool)? {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        // A workspace that already exists, longest name first so “Impôts 2026” wins over “Impôts”.
        for name in known.sorted(by: { $0.count > $1.count }) where !name.isEmpty {
            if let range = text.range(of: name, options: options) {
                // Removes “dans l'espace” along with the name when it comes right before it.
                let before = text[..<range.lowerBound]
                var start = range.lowerBound
                if let marker = markers.lazy.compactMap({ before.range(of: $0, options: options.union(.backwards)) }).first,
                   before[marker.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty {
                    start = marker.lowerBound
                }
                text.removeSubrange(start..<range.upperBound)
                return (name, true)
            }
        }
        // A new workspace: “dans l'espace Voyage Japon”, “to the workspace Taxes”.
        for marker in markers {
            guard let range = text.range(of: marker, options: options) else { continue }
            let rest = text[range.upperBound...]
            let end = rest.firstIndex { ".,;!?\n".contains($0) } ?? rest.endIndex
            let name = rest[..<end].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            text.removeSubrange(range.lowerBound..<end)
            return (name, false)
        }
        return nil
    }

    /// What comes right before a workspace name, longest first.
    private static let markers = [
        "dans l'espace de travail ", "dans mon espace de travail ", "à l'espace de travail ",
        "dans l'espace ", "dans mon espace ", "à l'espace ", "vers l'espace ", "l'espace ",
        "to the workspace ", "into the workspace ", "in the workspace ", "to workspace ", "into workspace ",
        "in workspace ", "workspace ",
    ]

    private static let stopWords: Set<String> = [
        "trouve", "trouver", "cherche", "chercher", "montre", "montrer", "affiche", "afficher", "range", "ranger",
        "mes", "les", "des", "une", "mon", "ton", "tes", "ses", "pour", "dans", "avec", "sur", "qui", "que", "quoi",
        "fichier", "fichiers", "document", "documents", "tous", "toutes", "tout", "moi", "sont", "est", "ils", "elles",
        "find", "search", "show", "look", "for", "the", "and", "all", "files", "file", "with", "from", "into", "that",
        "put", "them", "mets", "mettre", "ajoute", "ajouter", "add", "please", "stp", "svp", "cette", "ces", "cet",
        "annee", "annees", "year", "years", "this", "last", "derniere", "dernier", "derniers", "dernieres", "mois",
        "month", "semaine", "week", "aussi", "also", "nos", "vos", "votre", "leur", "leurs", "our", "your", "pdf",
        "pdfs", "ici", "here", "fais", "faire", "peux", "can", "you", "could", "would", "renomme", "renommer",
        "rename", "sans", "without", "don", "copie", "copies", "rassemble", "rassembler", "gather", "collect",
        "regroupe", "regrouper", "organise", "organiser", "organize",
    ]
}
