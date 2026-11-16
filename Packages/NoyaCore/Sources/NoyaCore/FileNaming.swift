import Foundation

/// Spots unclear file names and proposes better ones from what a document says.
public enum FileNaming {
    /// Whether a name says nothing about the file, such as “scan0012.pdf” or “document(3).pdf”.
    public static func isUnclear(_ fileName: String) -> Bool {
        let base = (fileName as NSString).deletingPathExtension
        let plain = AssistantParser.normalize(base).trimmingCharacters(in: .whitespaces)
        if plain.count <= 3 { return true }

        // The default name of a screenshot: “Screenshot 2026-11-02 at 10.12.44”.
        if FileCategory.isScreenshotName(fileName) { return true }

        // Only digits, punctuation and spaces: “20261012_1432”.
        if plain.allSatisfy({ !$0.isLetter }) { return true }

        // A generic word followed by numbers: “scan0012”, “document (3)”, “IMG_4021”, “Sans titre 2”.
        let generic = [
            "scan", "scanned", "numerisation", "document", "doc", "file", "fichier", "download", "telechargement",
            "img", "image", "photo", "dsc", "pxl", "capture", "screenshot", "untitled", "sans titre", "pdf",
            "print", "impression", "export", "attachment", "piece jointe", "pj",
        ]
        for word in generic where plain.hasPrefix(word) {
            let rest = plain.dropFirst(word.count)
            if rest.allSatisfy({ !$0.isLetter }) { return true }
        }

        // Identifiers such as “3f9a2c1e-…” or “a8F3kQ9zX2”.
        let letters = plain.filter(\.isLetter).count
        let digits = plain.filter(\.isNumber).count
        if !plain.contains(" "), plain.count >= 12, digits >= 4, letters >= 1 {
            let hexadecimal = plain.allSatisfy { $0.isHexDigit || $0 == "-" || $0 == "_" }
            if hexadecimal || Double(digits) / Double(plain.count) > 0.3 { return true }
        }
        return false
    }

    /// A name for a document, such as “Facture EDF octobre 2026”, from its text.
    ///
    /// - Parameters:
    ///   - text: The beginning of the document.
    ///   - title: What the document is, such as “Facture”.
    ///   - languageCode: The language of the month names, “fr” or “en”.
    /// - Returns: `nil` when the text gives neither who sent the document nor when.
    public static func proposedName(fromText text: String, title: String, languageCode: String = "fr") -> String? {
        let issuer = issuer(in: text)
        let date = firstDate(in: text)
        guard issuer != nil || date != nil else { return nil }

        var parts = [title]
        if let issuer { parts.append(issuer) }
        if let date {
            parts.append(monthName(date.month, languageCode: languageCode) + " " + String(date.year))
        }
        return sanitized(parts.joined(separator: " "))
    }

    /// A name for a screenshot from the text found in it, such as “Capture – Réglages Système”.
    public static func proposedScreenshotName(fromText text: String, prefix: String) -> String? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let title = lines.first { line in
            let letters = line.filter(\.isLetter).count
            return letters >= 4 && line.count <= 40 && Double(letters) / Double(line.count) > 0.6
        }
        guard let title else { return nil }
        let words = title.split(separator: " ").prefix(5).joined(separator: " ")
        return sanitized("\(prefix) – \(words)")
    }

    /// Removes the characters macOS does not accept in file names and trims the length.
    public static func sanitized(_ name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .\"'«»“”"))
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        if cleaned.count > 80 {
            cleaned = String(cleaned.prefix(80)).trimmingCharacters(in: .whitespaces)
        }
        return cleaned
    }

    // MARK: - Issuer

    /// Who sent the document, guessed from the web or mail domains it mentions, or a company name.
    static func issuer(in text: String) -> String? {
        let personal: Set<String> = [
            "gmail", "googlemail", "hotmail", "outlook", "live", "msn", "yahoo", "icloud", "me", "mac", "aol",
            "proton", "protonmail", "gmx", "laposte", "wanadoo", "sfr", "neuf", "bbox", "club-internet",
            "example", "www", "mail", "email", "w3",
        ]
        var counts: [String: Int] = [:]
        var order: [String] = []
        let pattern = try? NSRegularExpression(pattern: "(?:@|www\\.|https?://)((?:[a-z0-9-]+\\.)+[a-z]{2,})", options: [.caseInsensitive])
        let range = NSRange(text.startIndex..., in: text)
        pattern?.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let found = Range(match.range(at: 1), in: text) else { return }
            // The name before the top-level domain: “free” in “subscribe.free.fr”, “acme” in “acme.co.uk”.
            let labels = text[found].lowercased().split(separator: ".").map(String.init)
            guard labels.count >= 2 else { return }
            let secondLevel = ["co", "com", "org", "net", "gouv", "ac", "gov"]
            let name = labels.count >= 3 && secondLevel.contains(labels[labels.count - 2]) ? labels[labels.count - 3] : labels[labels.count - 2]
            guard !personal.contains(name), name.count >= 2 else { return }
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        if let best = order.max(by: { counts[$0]! < counts[$1]! || (counts[$0]! == counts[$1]! && order.firstIndex(of: $0)! > order.firstIndex(of: $1)!) }) {
            // Short names are usually acronyms, such as EDF or SFR.
            return best.count <= 3 ? best.uppercased() : best.prefix(1).uppercased() + best.dropFirst()
        }

        // A line naming a company: “ACME SAS”, “Dupont & Fils SARL”.
        let forms = ["SAS", "SASU", "SARL", "EURL", "SA", "SCI", "SNC", "Inc.", "Inc", "LLC", "Ltd", "GmbH"]
        for line in text.split(whereSeparator: \.isNewline).prefix(40) {
            let words = line.split(separator: " ").map(String.init)
            guard let index = words.firstIndex(where: { forms.contains($0.trimmingCharacters(in: CharacterSet(charactersIn: ",."))) }),
                  index > 0, index <= 4 else { continue }
            let name = words[..<index].joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            if name.filter(\.isLetter).count >= 2 { return name }
        }
        return nil
    }

    // MARK: - Dates

    struct MonthYear: Equatable {
        let month: Int
        let year: Int
    }

    /// The first date the text mentions, such as “12/10/2026”, “2026-10-12” or “octobre 2026”.
    static func firstDate(in text: String) -> MonthYear? {
        let plain = AssistantParser.normalize(text)
        var best: (offset: Int, date: MonthYear)?

        func consider(_ offset: Int, _ month: Int, _ year: Int) {
            guard (1...12).contains(month), (1990...2100).contains(year) else { return }
            if best == nil || offset < best!.offset {
                best = (offset, MonthYear(month: month, year: year))
            }
        }

        let range = NSRange(plain.startIndex..., in: plain)
        // 12/10/2026 or 12.10.2026 or 12-10-2026: day first, as in France.
        if let regex = try? NSRegularExpression(pattern: "\\b(\\d{1,2})[/.-](\\d{1,2})[/.-](\\d{4})\\b") {
            for match in regex.matches(in: plain, range: range) {
                let numbers = (1...3).compactMap { Range(match.range(at: $0), in: plain).flatMap { Int(plain[$0]) } }
                if numbers.count == 3 { consider(match.range.location, numbers[1], numbers[2]) }
            }
        }
        // 2026-10-12
        if let regex = try? NSRegularExpression(pattern: "\\b(\\d{4})-(\\d{2})-(\\d{2})\\b") {
            for match in regex.matches(in: plain, range: range) {
                let numbers = (1...2).compactMap { Range(match.range(at: $0), in: plain).flatMap { Int(plain[$0]) } }
                if numbers.count == 2 { consider(match.range.location, numbers[1], numbers[0]) }
            }
        }
        // octobre 2026, 12 octobre 2026, October 12, 2026
        let names = monthNames.map { $0.joined(separator: "|") }.joined(separator: "|")
        if let regex = try? NSRegularExpression(pattern: "\\b(\(names))\\.?\\s+(?:\\d{1,2},?\\s+)?(\\d{4})\\b") {
            for match in regex.matches(in: plain, range: range) {
                guard let nameRange = Range(match.range(at: 1), in: plain),
                      let yearRange = Range(match.range(at: 2), in: plain),
                      let year = Int(plain[yearRange]) else { continue }
                let name = String(plain[nameRange])
                if let month = monthNames.firstIndex(where: { $0.contains(name) }) {
                    consider(match.range.location, month + 1, year)
                }
            }
        }
        return best?.date
    }

    /// Month names without accents, in French then English, with common abbreviations.
    private static let monthNames: [[String]] = [
        ["janvier", "janv", "january", "jan"], ["fevrier", "fevr", "february", "feb"], ["mars", "march", "mar"],
        ["avril", "avr", "april", "apr"], ["mai", "may"], ["juin", "june", "jun"], ["juillet", "juil", "july", "jul"],
        ["aout", "august", "aug"], ["septembre", "sept", "september", "sep"], ["octobre", "oct", "october"],
        ["novembre", "nov", "november"], ["decembre", "dec", "december"],
    ]

    static func monthName(_ month: Int, languageCode: String) -> String {
        let french = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
        let english = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        let names = languageCode.hasPrefix("fr") ? french : english
        return names[max(0, min(11, month - 1))]
    }
}

/// Picks the sentences that best sum up a text, without any language model.
public enum Summarizer {
    public static func keySentences(in text: String, count: Int = 3) -> [String] {
        let sentences = splitSentences(text)
        guard sentences.count > count else { return sentences }

        var frequencies: [String: Int] = [:]
        let tokenized = sentences.map { words(in: $0) }
        for words in tokenized {
            for word in Set(words) { frequencies[word, default: 0] += 1 }
        }
        let scored = sentences.indices.map { index -> (Int, Double) in
            let words = tokenized[index]
            guard !words.isEmpty else { return (index, 0) }
            let total = words.reduce(0) { $0 + Double(frequencies[$1] ?? 0) }
            // Rewards sentences that share words with the rest, without favoring long ones too much,
            // and gives a little extra weight to the opening, where documents usually say what they are.
            let opening = index < 2 ? 1.2 : 1
            return (index, total / Double(words.count).squareRoot() * opening)
        }
        let chosen = scored.sorted { $0.1 > $1.1 }.prefix(count).map(\.0).sorted()
        return chosen.map { sentences[$0] }
    }

    static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let characters = Array(text.replacingOccurrences(of: "\r", with: ""))
        for (index, character) in characters.enumerated() {
            if character == "\n" {
                // A line break ends a sentence only after a blank line or a line that looks finished.
                let next = index + 1 < characters.count ? characters[index + 1] : "\n"
                if next == "\n" || current.last.map({ ".!?:".contains($0) }) == true {
                    flush(&current, into: &sentences)
                } else {
                    current.append(" ")
                }
                continue
            }
            current.append(character)
            if ".!?".contains(character) {
                let next = index + 1 < characters.count ? characters[index + 1] : " "
                if next == " " || next == "\n" { flush(&current, into: &sentences) }
            }
        }
        flush(&current, into: &sentences)
        return sentences
    }

    private static func flush(_ current: inout String, into sentences: inout [String]) {
        let sentence = current.trimmingCharacters(in: .whitespaces)
        if sentence.filter(\.isLetter).count >= 12 {
            sentences.append(sentence)
        }
        current = ""
    }

    private static func words(in sentence: String) -> [String] {
        AssistantParser.normalize(sentence)
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 4 && !common.contains($0) }
    }

    private static let common: Set<String> = [
        "dans", "pour", "avec", "sont", "mais", "plus", "nous", "vous", "elle", "elles", "leur", "leurs", "cette",
        "comme", "tout", "tous", "aussi", "fait", "etre", "avoir", "this", "that", "with", "from", "have", "were",
        "will", "your", "they", "their", "there", "which", "would", "about", "been", "into", "than", "then",
    ]
}
