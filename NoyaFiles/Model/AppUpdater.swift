import Foundation
import Observation
import Sparkle

/// Keeps NOYA Files up to date with Sparkle.
///
/// New versions are announced by the `appcast.xml` file attached to each GitHub release
/// (`SUFeedURL` in `Config/Info.plist`). Each update is signed, and Sparkle installs it only
/// when the signature matches the public key built into the app (`SUPublicEDKey`).
/// Checking only asks GitHub whether a newer version exists: nothing about the Mac or its
/// files is sent.
@MainActor
@Observable
final class AppUpdater {
    static let shared = AppUpdater()

    @ObservationIgnored private let controller: SPUStandardUpdaterController

    /// Mirrors Sparkle's setting so SwiftUI views update when it changes.
    private(set) var checksAutomatically: Bool

    /// Whether the person has chosen yet. Until then, Sparkle would ask on its own.
    var hasChosenAutomaticChecks: Bool {
        UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") != nil
    }

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
    }

    /// Looks for a new version now, and shows the result.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Turns the daily check for new versions on or off.
    func setChecksAutomatically(_ isOn: Bool) {
        controller.updater.automaticallyChecksForUpdates = isOn
        checksAutomatically = isOn
    }

    /// When Sparkle last looked for a new version.
    var lastCheck: Date? {
        controller.updater.lastUpdateCheckDate
    }

    /// The version running now, such as “0.2.0”.
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
