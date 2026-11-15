import Foundation

/// Recognises installers, such as `Sketch-101.2.dmg`, for apps that are already installed.
public enum InstalledAppMatcher {
    /// The product an installer is for, reduced to lowercase letters and digits.
    ///
    /// Versions, architectures and words such as "installer" or "setup" are dropped,
    /// so `Figma-installer-universal.dmg` becomes `figma`.
    public static func productKey(fromInstaller fileName: String) -> String {
        var name = fileName
        let fileExtension = FileCategory.pathExtension(of: fileName)
        if !fileExtension.isEmpty {
            name = String(name.dropLast(fileExtension.count + 1))
        }
        return key(from: name, droppingNoise: true)
    }

    /// The display name of the installed app an installer is for, if any.
    ///
    /// - Parameters:
    ///   - installerName: The installer's file name, such as `Raycast-1.80.dmg`.
    ///   - appNames: Names of installed apps, with or without the `.app` extension.
    public static func installedApp(forInstaller installerName: String, among appNames: [String]) -> String? {
        let product = productKey(fromInstaller: installerName)
        guard product.count >= 3 else { return nil }

        var bestMatch: (name: String, length: Int)?
        for appName in appNames {
            let displayName = appName.hasSuffix(".app") ? String(appName.dropLast(4)) : appName
            let appKey = key(from: displayName, droppingNoise: false)
            guard appKey.count >= 3 else { continue }

            let matches = appKey == product
                || (appKey.hasPrefix(product) && product.count >= 4)
                || (product.hasPrefix(appKey) && appKey.count >= 4)
            if matches, appKey.count > (bestMatch?.length ?? 0) {
                bestMatch = (displayName, appKey.count)
            }
        }
        return bestMatch?.name
    }

    /// Names of the apps installed in the usual Applications folders.
    public static func installedAppNames(fileManager: FileManager = .default) -> [String] {
        var folders = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
        folders.append(URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true))
        return folders.flatMap { folder in
            ((try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".app") }
        }
    }

    private static let noiseWords: Set<String> = [
        "install", "installer", "setup", "mac", "macos", "osx", "os", "x", "universal", "arm64", "arm",
        "x64", "x86", "x8664", "amd64", "intel", "apple", "silicon", "latest", "darwin", "full",
        "release", "stable", "dmg", "pkg", "for", "the", "app",
    ]

    private static func key(from name: String, droppingNoise: Bool) -> String {
        let words = name.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        let kept = words.filter { word in
            guard droppingNoise else { return true }
            if noiseWords.contains(word) { return false }
            // Versions such as "101", "2", "v3" or "1b".
            if word.first?.isNumber == true { return false }
            if word.count > 1, word.first == "v", word.dropFirst().allSatisfy(\.isNumber) { return false }
            return true
        }
        return kept.joined().filter { $0.isLetter || $0.isNumber }
    }
}
