import Foundation
import Testing
@testable import NoyaCore

/// A throwaway folder that deletes itself when the test ends.
final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoyaCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func file(_ relativePath: String, bytes: Int) throws -> URL {
        let fileURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(count: bytes).write(to: fileURL)
        return fileURL
    }

    @discardableResult
    func folder(_ relativePath: String) throws -> URL {
        let folderURL = url.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }
}

@Suite("Reading the file system")
struct FileSystemTests {
    @Test("Lists files, folders and hidden entries with their metadata")
    func listsFolderContents() throws {
        let temp = try TemporaryFolder()
        try temp.file("Report.pdf", bytes: 1_500)
        try temp.file(".secret", bytes: 10)
        try temp.folder("Projects")

        let items = try DirectoryReader().items(in: temp.url)
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })

        #expect(items.count == 3)

        let report = try #require(byName["Report.pdf"])
        #expect(report.kind == .file)
        #expect(report.size == 1_500)
        #expect(report.category == .pdfs)
        #expect(report.isHidden == false)
        #expect(report.modificationDate != nil)

        let secret = try #require(byName[".secret"])
        #expect(secret.isHidden)

        let projects = try #require(byName["Projects"])
        #expect(projects.kind == .folder)
        #expect(projects.isFolder)
        #expect(projects.size == 0)
        #expect(projects.category == nil)
    }

    @Test("Reading a missing folder throws")
    func missingFolderThrows() throws {
        let temp = try TemporaryFolder()
        let missing = temp.url.appendingPathComponent("does-not-exist")
        #expect(throws: (any Error).self) {
            try DirectoryReader().items(in: missing)
        }
    }

    @Test("Measures nested folders recursively")
    func measuresFolders() throws {
        let temp = try TemporaryFolder()
        try temp.file("Photos/a.jpg", bytes: 1_000)
        try temp.file("Photos/Trip/b.jpg", bytes: 2_000)
        try temp.file("Photos/.DS_Store", bytes: 50)
        try temp.folder("Photos/Empty")

        let measurement = FolderSizer.measure(temp.url.appendingPathComponent("Photos"))

        #expect(measurement.bytes == 3_050)
        #expect(measurement.fileCount == 3)
        // a.jpg, Trip and Empty; .DS_Store is hidden.
        #expect(measurement.itemCount == 3)
    }

    @Test("Measuring an empty folder returns zero")
    func measuresEmptyFolder() throws {
        let temp = try TemporaryFolder()
        let measurement = FolderSizer.measure(temp.url)
        #expect(measurement == FolderSizer.Measurement(bytes: 0, fileCount: 0, itemCount: 0))
    }
}
