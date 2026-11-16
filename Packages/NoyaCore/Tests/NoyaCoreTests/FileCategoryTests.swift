import Testing
@testable import NoyaCore

@Suite("File categories")
struct FileCategoryTests {
    @Test("Classifies common extensions", arguments: [
        ("Report.pdf", FileCategory.pdfs),
        ("notes.TXT", .documents),
        ("Budget 2026.xlsx", .documents),
        ("Holiday.HEIC", .images),
        ("clip.mov", .videos),
        ("song.flac", .audio),
        ("backup.tar.gz", .archives),
        ("Installer.dmg", .installers),
        ("Shoji.app", .installers),
        ("main.swift", .code),
        ("mystery.xyz", .other),
        ("README", .other),
    ])
    func classifiesByExtension(fileName: String, expected: FileCategory) {
        #expect(FileCategory.classify(fileName: fileName) == expected)
    }

    @Test("Recognises screenshots in several languages", arguments: [
        "Screenshot 2026-11-14 at 10.12.03.png",
        "Screen Shot 2020-01-01 at 09.00.00.png",
        "Capture d\u{2019}écran 2026-11-14 à 10.12.03.png",
        "Capture d'écran 2026-11-14.png",
        "CleanShot 2026-11-14.jpg",
    ])
    func recognisesScreenshots(fileName: String) {
        #expect(FileCategory.classify(fileName: fileName) == .screenshots)
    }

    @Test("A screenshot-like name that is not an image stays in its own category")
    func screenshotNameOnVideo() {
        #expect(FileCategory.classify(fileName: "Screenshot recording.mov") == .videos)
    }

    @Test("Extracts extensions the way users expect", arguments: [
        ("photo.JPG", "jpg"),
        ("archive.tar.gz", "gz"),
        (".zshrc", ""),
        ("no-extension", ""),
        ("trailing.", ""),
    ])
    func extractsExtensions(fileName: String, expected: String) {
        #expect(FileCategory.pathExtension(of: fileName) == expected)
    }
}
