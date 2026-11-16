import Foundation
import Testing
@testable import NoyaCore

private let root = URL(fileURLWithPath: "/Users/test/Downloads", isDirectory: true)
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 86_400

private func file(
    _ name: String,
    size: Int64,
    hidden: Bool = false,
    modified: Date? = now,
    added: Date? = nil
) -> FileItem {
    FileItem(
        url: root.appendingPathComponent(name),
        kind: .file,
        isHidden: hidden,
        size: size,
        modificationDate: modified,
        addedDate: added
    )
}

private func folder(_ name: String, hidden: Bool = false) -> FileItem {
    FileItem(url: root.appendingPathComponent(name, isDirectory: true), kind: .folder, isHidden: hidden)
}

@Suite("Folder insights")
struct FolderInsightsTests {
    let items = [
        folder("Projects"),
        folder(".cache", hidden: true),
        file("movie.mp4", size: 5_000),
        file("clip.mov", size: 1_000),
        file("photo.png", size: 300),
        file(".hidden.txt", size: 20, hidden: true),
        FileItem(url: root.appendingPathComponent("Tool.app", isDirectory: true), kind: .package),
    ]

    var measurements: [URL: FolderSizer.Measurement] {
        [
            root.appendingPathComponent("Projects", isDirectory: true): .init(bytes: 2_000, fileCount: 12, itemCount: 4),
            root.appendingPathComponent(".cache", isDirectory: true): .init(bytes: 700, fileCount: 3, itemCount: 3),
        ]
    }

    @Test("Totals visible items and ranks what takes the space")
    func summarisesVisibleItems() {
        let insights = FolderInsights(items: items, measurements: measurements, includeHidden: false)

        #expect(insights.totalBytes == 8_300)
        #expect(insights.folderCount == 1)
        #expect(insights.looseFileCount == 4)
        #expect(insights.hiddenItemCount == 2)
        #expect(insights.hiddenBytes == 720)
        #expect(insights.unmeasuredCount == 1)

        #expect(insights.entries.map(\.subject) == [
            .category(.videos),
            .folder(root.appendingPathComponent("Projects", isDirectory: true), name: "Projects"),
            .category(.images),
            .category(.installers),
        ])
        #expect(insights.entries.first?.bytes == 6_000)
        #expect(insights.entries.first?.fileCount == 2)
    }

    @Test("Includes hidden items when asked")
    func includesHiddenItems() {
        let insights = FolderInsights(items: items, measurements: measurements, includeHidden: true)

        #expect(insights.totalBytes == 9_020)
        #expect(insights.folderCount == 2)
        #expect(insights.looseFileCount == 5)
        #expect(insights.hiddenBytes == 720)
    }

    @Test("An empty folder has empty insights")
    func emptyFolder() {
        let insights = FolderInsights(items: [], measurements: [:], includeHidden: false)
        #expect(insights.totalBytes == 0)
        #expect(insights.entries.isEmpty)
    }
}

@Suite("Cleanup suggestions")
struct CleanupAdvisorTests {
    @Test("Suggests disk images and packages but not apps")
    func suggestsInstallers() throws {
        let items = [
            file("Setup.dmg", size: 40_000),
            file("Driver.pkg", size: 4_000),
            FileItem(url: root.appendingPathComponent("Tool.app", isDirectory: true), kind: .package),
            file("notes.txt", size: 10),
        ]

        let suggestions = CleanupAdvisor.suggestions(for: items, now: now)
        let installers = try #require(suggestions.first { $0.kind == .installers })

        #expect(installers.count == 2)
        #expect(installers.bytes == 44_000)
    }

    @Test("Suggests files with no recent activity")
    func suggestsStaleFiles() throws {
        let items = [
            file("old.pdf", size: 100, modified: now - 200 * day, added: now - 120 * day),
            file("fresh-download.pdf", size: 100, modified: now - 400 * day, added: now - 2 * day),
            file("recent.pdf", size: 100, modified: now - 10 * day),
            file(".old-hidden", size: 100, hidden: true, modified: now - 400 * day),
        ]

        let suggestions = CleanupAdvisor.suggestions(for: items, now: now)
        let stale = try #require(suggestions.first { $0.kind == .staleFiles(days: 90) })

        #expect(stale.itemURLs == [root.appendingPathComponent("old.pdf")])
        #expect(stale.bytes == 100)
    }

    @Test("Has nothing to say about a tidy folder")
    func noSuggestions() {
        let suggestions = CleanupAdvisor.suggestions(for: [file("recent.pdf", size: 1)], now: now)
        #expect(suggestions.isEmpty)
    }
}

@Suite("Grouping")
struct GroupingTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test("Groups loose files by category, largest first")
    func groupsByCategory() {
        let groups = Grouping.byCategory([
            folder("Projects"),
            file("a.png", size: 10),
            file("b.png", size: 10),
            file("movie.mp4", size: 500),
        ])

        #expect(groups.map(\.category) == [.videos, .images])
        #expect(groups.last?.items.count == 2)
        #expect(groups.last?.bytes == 20)
    }

    @Test("Puts dates in the right bucket", arguments: [
        (0.0, DateBucket.today),
        (1.0, .yesterday),
        (5.0, .previous7Days),
        (20.0, .previous30Days),
        (800.0, .older),
    ])
    func bucketsDates(daysAgo: Double, expected: DateBucket) {
        let date = now - daysAgo * day
        #expect(DateBucket.bucket(for: date, now: now, calendar: calendar) == expected)
    }

    @Test("A missing date is treated as old")
    func missingDate() {
        #expect(DateBucket.bucket(for: nil, now: now, calendar: calendar) == .older)
    }

    @Test("Groups by date, most recent first, skipping empty buckets")
    func groupsByDate() {
        let groups = Grouping.byDate([
            file("old.txt", size: 1, modified: now - 800 * day),
            file("today.txt", size: 1, modified: now),
        ], now: now, calendar: calendar)

        #expect(groups.map(\.bucket) == [.today, .older])
    }
}

@Suite("Installed apps")
struct InstalledAppMatcherTests {
    let apps = ["Sketch.app", "Figma.app", "zoom.us.app", "Visual Studio Code.app", "Raycast.app", "Notes.app"]

    @Test("Reduces installer names to their product", arguments: [
        ("Sketch-101.2.dmg", "sketch"),
        ("Figma-installer-universal.dmg", "figma"),
        ("Install Zoom.pkg", "zoom"),
        ("Raycast_v1.80.3_arm64.dmg", "raycast"),
        ("googlechrome.dmg", "googlechrome"),
    ])
    func productKeys(fileName: String, expected: String) {
        #expect(InstalledAppMatcher.productKey(fromInstaller: fileName) == expected)
    }

    @Test("Finds the installed app an installer is for", arguments: [
        ("Sketch-101.2.dmg", "Sketch"),
        ("Figma-installer.dmg", "Figma"),
        ("zoomusInstallerFull.pkg", "zoom.us"),
        ("Raycast_v1.80.3_arm64.dmg", "Raycast"),
    ])
    func matches(installer: String, expected: String) {
        #expect(InstalledAppMatcher.installedApp(forInstaller: installer, among: apps) == expected)
    }

    @Test("Ignores installers for apps that are not installed", arguments: [
        "Blender-4.2.dmg",
        "setup.pkg",
        "v2.dmg",
    ])
    func noMatch(installer: String) {
        #expect(InstalledAppMatcher.installedApp(forInstaller: installer, among: apps) == nil)
    }

    @Test("The installers suggestion lists the ones already installed")
    func suggestionListsMatches() throws {
        let items = [file("Sketch-101.2.dmg", size: 300), file("Blender-4.2.dmg", size: 500)]
        let suggestions = CleanupAdvisor.suggestions(for: items, now: now, installedAppNames: apps)
        let installers = try #require(suggestions.first { $0.kind == .installers })

        #expect(installers.count == 2)
        #expect(installers.installedMatches.map(\.appName) == ["Sketch"])
        #expect(installers.installedMatches.first?.bytes == 300)
    }
}
