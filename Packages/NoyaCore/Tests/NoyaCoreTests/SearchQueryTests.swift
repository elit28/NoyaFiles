import Testing
@testable import NoyaCore

@Suite("Search queries")
struct SearchQueryTests {
    @Test("Empty criteria produce no query")
    func empty() {
        #expect(SearchCriteria().spotlightQuery == nil)
        #expect(SearchCriteria(text: "   ").spotlightQuery == nil)
    }

    @Test("Each word must match the name or the contents")
    func words() {
        let query = SearchCriteria(text: "facture 2026").spotlightQuery
        #expect(query == #"(kMDItemFSName == "*facture*"cd || kMDItemTextContent == "*facture*"cd) && (kMDItemFSName == "*2026*"cd || kMDItemTextContent == "*2026*"cd)"#)
    }

    @Test("Searching names only skips the contents")
    func namesOnly() {
        let query = SearchCriteria(text: "budget", searchesContents: false).spotlightQuery
        #expect(query == #"kMDItemFSName == "*budget*"cd"#)
    }

    @Test("Combines kinds, period, size and tags")
    func filters() {
        let criteria = SearchCriteria(
            text: "",
            kinds: [.pdfs, .images],
            period: .year,
            minimumSize: 102_400,
            tags: ["atlas"]
        )
        #expect(criteria.spotlightQuery == #"(kMDItemContentTypeTree == "public.image" || kMDItemContentTypeTree == "com.adobe.pdf") && kMDItemFSContentChangeDate >= $time.this_year && kMDItemFSSize >= 102400 && kMDItemUserTags == "atlas"cd"#)
    }

    @Test("Escapes quotes and wildcards typed by the user")
    func escaping() {
        #expect(SearchCriteria.escape(#"a"b*c?d\e"#) == #"a\"b\*c\?d\\e"#)
    }

    @Test("Makes snippets around a word")
    func snippets() {
        let text = String(repeating: "x", count: 60) + " the Facture n° 118\nwas paid " + String(repeating: "y", count: 60)
        let snippet = SnippetMaker.snippet(around: "facture", in: text, radius: 10)
        #expect(snippet == "… xxxxx the Facture n° 118 wa …")
        #expect(SnippetMaker.snippet(around: "absent", in: text) == nil)
    }
}
