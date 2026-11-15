import Foundation
import Observation

struct SidebarItem: Identifiable, Hashable {
    let url: URL
    let title: String
    let symbolName: String

    var id: URL { url }
}

struct DiskUsage: Equatable {
    let name: String
    let availableBytes: Int64
    let totalBytes: Int64

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(totalBytes - availableBytes) / Double(totalBytes)
    }
}

/// The places listed in the sidebar and the state of the startup disk.
@MainActor
@Observable
final class SidebarModel {
    private(set) var favorites: [SidebarItem] = []
    private(set) var locations: [SidebarItem] = []
    private(set) var disk: DiskUsage?

    init() {
        refresh()
    }

    func refresh() {
        favorites = Self.makeFavorites()
        locations = Self.makeLocations()
        refreshDiskUsage()
    }

    func refreshDiskUsage() {
        let usage = Self.startupDiskUsage()
        if usage != disk { disk = usage }
    }

    private static func makeFavorites() -> [SidebarItem] {
        let fileManager = FileManager.default
        var items: [SidebarItem] = []

        func add(_ directory: FileManager.SearchPathDirectory, symbolName: String) {
            guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else { return }
            items.append(SidebarItem(
                url: url.canonicalDirectory,
                title: fileManager.displayName(atPath: url.path),
                symbolName: symbolName
            ))
        }

        add(.desktopDirectory, symbolName: "menubar.dock.rectangle")
        add(.documentDirectory, symbolName: "doc")
        add(.downloadsDirectory, symbolName: "arrow.down.circle")

        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        items.append(SidebarItem(
            url: applications.canonicalDirectory,
            title: fileManager.displayName(atPath: applications.path),
            symbolName: "square.grid.2x2"
        ))
        return items
    }

    private static func makeLocations() -> [SidebarItem] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var items: [SidebarItem] = []

        let iCloudDrive = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if fileManager.fileExists(atPath: iCloudDrive.path) {
            items.append(SidebarItem(
                url: iCloudDrive.canonicalDirectory,
                title: String(localized: "iCloud Drive"),
                symbolName: "icloud"
            ))
        }

        items.append(SidebarItem(
            url: home.canonicalDirectory,
            title: fileManager.displayName(atPath: home.path),
            symbolName: "house"
        ))

        let volumeKeys: [URLResourceKey] = [.volumeLocalizedNameKey, .volumeIsInternalKey]
        let volumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: volumeKeys,
            options: [.skipHiddenVolumes]
        ) ?? []
        for volume in volumes {
            let values = try? volume.resourceValues(forKeys: Set(volumeKeys))
            items.append(SidebarItem(
                url: volume.canonicalDirectory,
                title: values?.volumeLocalizedName ?? volume.lastPathComponent,
                symbolName: values?.volumeIsInternal == false ? "externaldrive" : "internaldrive"
            ))
        }

        if let trash = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first {
            items.append(SidebarItem(
                url: trash.canonicalDirectory,
                title: String(localized: "Trash"),
                symbolName: "trash"
            ))
        }
        return items
    }

    private static func startupDiskUsage() -> DiskUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard
            let values = try? home.resourceValues(forKeys: keys),
            let total = values.volumeTotalCapacity
        else { return nil }

        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let name = (try? root.resourceValues(forKeys: [.volumeLocalizedNameKey]))?.volumeLocalizedName
        return DiskUsage(
            name: name ?? FileManager.default.displayName(atPath: "/"),
            availableBytes: values.volumeAvailableCapacityForImportantUsage ?? 0,
            totalBytes: Int64(total)
        )
    }
}
