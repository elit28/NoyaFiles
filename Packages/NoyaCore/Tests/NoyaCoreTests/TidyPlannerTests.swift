import Foundation
import Testing
@testable import NoyaCore

@Suite("Tidying Downloads")
struct TidyPlannerTests {
    let downloads = URL(fileURLWithPath: "/Users/test/Downloads", isDirectory: true)
    let pictures = URL(fileURLWithPath: "/Users/test/Pictures/Downloaded", isDirectory: true)
    let pdfs = URL(fileURLWithPath: "/Users/test/Documents/PDF", isDirectory: true)
    let archive = URL(fileURLWithPath: "/Users/test/Downloads/Archive", isDirectory: true)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func file(_ name: String, size: Int64 = 10, daysAgo: Double = 1, hidden: Bool = false) -> FileItem {
        let date = now - daysAgo * 86_400
        return FileItem(
            url: downloads.appendingPathComponent(name),
            kind: .file,
            isHidden: hidden,
            size: size,
            modificationDate: date,
            addedDate: date
        )
    }

    var rules: [TidyRule] {
        [
            TidyRule(kind: .installedInstallers, isEnabled: true, destination: nil),
            TidyRule(kind: .screenshots, isEnabled: true, destination: pictures.appendingPathComponent("Screenshots")),
            TidyRule(kind: .images, isEnabled: true, destination: pictures),
            TidyRule(kind: .pdfs, isEnabled: true, destination: pdfs),
            TidyRule(kind: .videos, isEnabled: false, destination: nil),
            TidyRule(kind: .staleFiles, isEnabled: true, destination: archive),
        ]
    }

    @Test("Sends each file to the first rule that claims it")
    func plansMoves() {
        let items = [
            file("photo.jpg", size: 100),
            file("Screenshot 2026-11-14 at 10.00.00.png", size: 20),
            file("invoice.pdf", size: 30),
            file("Sketch-101.dmg", size: 500),
            file("Blender-4.2.dmg", size: 700),
            file("movie.mov", size: 900),
            file("old-notes.txt", daysAgo: 200),
            file(".DS_Store", hidden: true),
            FileItem(url: downloads.appendingPathComponent("Projects", isDirectory: true), kind: .folder),
        ]
        let plan = TidyPlanner.plan(for: items, rules: rules, installedAppNames: ["Sketch.app"], now: now)

        #expect(plan.moves(for: .images).map(\.item.name) == ["photo.jpg"])
        #expect(plan.moves(for: .screenshots).count == 1)
        #expect(plan.moves(for: .pdfs).first?.destination == pdfs)
        #expect(plan.moves(for: .installedInstallers).map(\.item.name) == ["Sketch-101.dmg"])
        #expect(plan.moves(for: .installedInstallers).first?.destination == nil)
        #expect(plan.moves(for: .staleFiles).map(\.item.name) == ["old-notes.txt"])
        #expect(plan.moves(for: .videos).isEmpty)
        #expect(plan.remainingCount == 2)
        #expect(plan.totalBytes == 100 + 20 + 30 + 500 + 10)
    }

    @Test("Leaves files that are already in their destination")
    func skipsFilesInPlace() {
        let inPlace = FileItem(url: archive.appendingPathComponent("old.txt"), kind: .file, size: 1, modificationDate: now - 300 * 86_400)
        let plan = TidyPlanner.plan(for: [inPlace], rules: rules, installedAppNames: [], now: now)
        #expect(plan.moves.isEmpty)
        #expect(plan.remainingCount == 1)
    }
}
