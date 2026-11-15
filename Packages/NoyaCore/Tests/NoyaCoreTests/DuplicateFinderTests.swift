import Foundation
import Testing
@testable import NoyaCore

@Suite("Duplicates")
struct DuplicateFinderTests {
    private func write(_ text: String, to name: String, in folder: TemporaryFolder, modified: Date) throws -> FileItem {
        let url = folder.url.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return FileItem(
            url: url,
            kind: .file,
            size: Int64(text.utf8.count),
            modificationDate: modified
        )
    }

    @Test("Groups files with identical contents and ignores look-alikes")
    func findsDuplicates() throws {
        let temp = try TemporaryFolder()
        let old = Date(timeIntervalSince1970: 1_000_000)
        let recent = Date(timeIntervalSince1970: 2_000_000)
        let beach = try write("sunny beach", to: "Plage.jpg", in: temp, modified: old)
        let beachCopy = try write("sunny beach", to: "Plage (1).jpg", in: temp, modified: recent)
        let sameSize = try write("rainy beach", to: "Pluie.jpg", in: temp, modified: old)
        let unique = try write("mountains", to: "Montagne.jpg", in: temp, modified: old)

        let groups = DuplicateFinder.duplicateGroups(in: [beach, beachCopy, sameSize, unique])

        #expect(groups.count == 1)
        #expect(Set(groups[0].map(\.name)) == ["Plage.jpg", "Plage (1).jpg"])
        #expect(DuplicateFinder.reclaimableBytes(in: groups) == 11)
        #expect(DuplicateFinder.extraCopies(in: groups).map(\.name) == ["Plage.jpg"])
    }

    @Test("Has nothing to report when every file is different")
    func noDuplicates() throws {
        let temp = try TemporaryFolder()
        let now = Date()
        let items = [
            try write("a", to: "a.txt", in: temp, modified: now),
            try write("bb", to: "b.txt", in: temp, modified: now),
        ]
        #expect(DuplicateFinder.duplicateGroups(in: items).isEmpty)
    }

    @Test("Groups files by format, largest first")
    func groupsByFormat() {
        let root = URL(fileURLWithPath: "/tmp")
        let items = [
            FileItem(url: root.appendingPathComponent("a.png"), kind: .file, size: 10),
            FileItem(url: root.appendingPathComponent("b.PNG"), kind: .file, size: 15),
            FileItem(url: root.appendingPathComponent("c.jpg"), kind: .file, size: 40),
        ]
        let formats = Grouping.byFormat(items)
        #expect(formats.map(\.format) == ["JPG", "PNG"])
        #expect(formats.last?.count == 2)
        #expect(formats.last?.bytes == 25)
    }
}
