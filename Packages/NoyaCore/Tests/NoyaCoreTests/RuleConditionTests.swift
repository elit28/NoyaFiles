import Foundation
import Testing
@testable import NoyaCore

@Suite("Smart rules")
struct RuleConditionTests {
    let folder = URL(fileURLWithPath: "/Users/test/Downloads", isDirectory: true)

    func file(_ name: String) -> FileItem {
        FileItem(url: folder.appendingPathComponent(name), kind: .file, size: 1)
    }

    @Test("Matches names ignoring case and accents", arguments: [
        ("Facture 2026-118.pdf", true),
        ("facture-edf.PDF", true),
        ("Relevé FACTURÉ.pdf", true),
        ("Devis 12.pdf", false),
    ])
    func nameContains(name: String, expected: Bool) {
        #expect(RuleCondition.nameContains("facture", extensions: []).matches(file(name)) == expected)
    }

    @Test("Limits name rules to some extensions")
    func extensions() {
        let rule = RuleCondition.nameContains("facture", extensions: [".pdf"])
        #expect(rule.matches(file("Facture.pdf")))
        #expect(!rule.matches(file("Facture.docx")))
    }

    @Test("Matches Finder tags, with or without a hash sign")
    func tags() {
        let rule = RuleCondition.tagged("#Atlas")
        #expect(rule.matches(file("brief.docx"), tags: ["atlas", "Urgent"]))
        #expect(!rule.matches(file("brief.docx"), tags: ["Urgent"]))
    }

    @Test("Matches categories but never folders")
    func categories() {
        let rule = RuleCondition.category(.pdfs)
        #expect(rule.matches(file("a.pdf")))
        #expect(!rule.matches(FileItem(url: folder.appendingPathComponent("pdf"), kind: .folder)))
    }

    @Test("Survives a round trip through JSON")
    func codable() throws {
        let rules: [RuleCondition] = [.nameContains("facture", extensions: ["pdf"]), .tagged("atlas"), .category(.images)]
        let data = try JSONEncoder().encode(rules)
        #expect(try JSONDecoder().decode([RuleCondition].self, from: data) == rules)
    }
}
