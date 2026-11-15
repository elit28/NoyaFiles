# NOYA Files

[Français](README.md) · **English**

**A smarter home for your files.**

NOYA Files is an open-source, native macOS file manager built with SwiftUI and AppKit.

Our mission is to make file management more beautiful, intuitive, powerful and efficient.

## Project status

🚧 **Under active development.** No stable public release is available yet.

## Planned features

- [ ] Beautiful native macOS interface
- [ ] List, grid and column views
- [ ] Intelligent file organization
- [ ] Downloads management
- [ ] Custom workspaces and collections
- [ ] Storage insights and cleanup tools
- [ ] Dual-pane navigation
- [ ] Advanced search
- [ ] Quick Look integration
- [ ] Developer tools
- [ ] Optional AI-powered features
- [ ] Dark and light themes
- [ ] English and French localization

Features listed above are planned and will be marked as available when implemented and tested.

## Download

Official macOS builds will be published in [GitHub Releases](https://github.com/elit28/NoyaFiles/releases) when available.

Until then, every automated build produces a test disk image: open the [Actions](https://github.com/elit28/NoyaFiles/actions) tab, pick the latest successful run of the **CI** workflow, and download the **NOYA-Files-macOS** artifact.

Until the app is signed with an Apple Developer ID certificate, macOS shows a warning on first launch. To open it anyway, drag **NOYA Files** to **Applications** and launch it once. Then open **System Settings › Privacy & Security** and click **Open Anyway**.

## Building from source

Requirements: macOS 14 Sonoma or later, and Xcode 16 or later.

1. Open `NoyaFiles.xcodeproj` in Xcode.
2. Pick the **NoyaFiles** scheme and run the app with ⌘R. Run the tests with ⌘U.

From the command line:

```bash
scripts/build-app.sh
```

```bash
scripts/make-dmg.sh
```

The first script produces `dist/NOYA Files.app`, a universal app for Apple silicon and Intel. The second packages it into `dist/NOYA-Files-<version>.dmg`.

## Project layout

| Folder | Contents |
| --- | --- |
| `NoyaFiles/` | The SwiftUI app: model, views, resources and translations. Any file added here is included in the Xcode project automatically. |
| `Packages/NoyaCore/` | Logic that does not depend on the interface (reading folders, categories, sizes, suggestions) and its tests. It also builds on Linux. |
| `scripts/` | Building, creating the `.dmg` and checking translations. |
| `.github/workflows/` | Automated builds and tests, and releases. |
| `Design/` | Design sources, including the app icon. |

## Releasing

Push a version tag such as `v0.2.0`. The **Release** workflow builds the app, creates the `.dmg` and prepares a draft release to review before publishing.

For the app to open without any warning, add these repository secrets: `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD`. This requires an Apple Developer account. The details are at the top of `.github/workflows/release.yml`.

## Technology

- Swift 6
- SwiftUI
- AppKit
- Native macOS frameworks

## Privacy

NOYA Files is designed around local-first processing and user control.

## Contributing

Contributions, bug reports and feature suggestions are welcome.

## License

NOYA Files is licensed under the [GNU General Public License v3.0 or later](LICENSE).

## Credits

Developed by NOYA 360.

NOYA Files is an independent project and is not affiliated with FileOS or Apple.
