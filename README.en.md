# NOYA Files

[Français](README.md) · **English**

**A smarter home for your files.**

NOYA Files is an open-source, native macOS file manager built with SwiftUI and AppKit.

Our mission is to make file management more beautiful, intuitive, powerful and efficient.

## Project status

🚧 **Under active development.** The first test release, [**0.1.0**](https://github.com/elit28/NoyaFiles/releases/tag/v0.1.0), is available (see [Download](#download)).

## Features

Every build launches the app on macOS 15 and macOS 26, in French and English, in light and dark mode, and takes a screenshot of each screen below. Checked items are verified that way; the others are written but still need checking by hand on a Mac.

- [x] Native macOS interface, light or dark theme following the system or your choice, accent color
- [x] Grid by kind, list and column views, grouping by kind or date
- [x] The size of every folder and an Insights panel: what takes up space, cleanup suggestions
- [x] Dual-pane navigation: copy (F5), move (F6), compare both folders
- [x] Workspaces and collections, with smart rules that gather files into them
- [x] Advanced search: names and document contents, filters, saved searches
- [x] Free Up Space: big files, developer caches, duplicates, installers, Trash
- [x] Tidy up Downloads, with a preview before anything moves
- [x] Developer tools: Git repositories, branches, changes, caches, built-in terminal
- [x] Optional, local AI assistant: find, gather, rename from contents (Apple Intelligence on macOS 26)
- [x] Guided first launch: disk access, language, view, favorites
- [x] English and French interface
- [ ] Quick Look with the space bar
- [ ] Undo after moving to the Trash, New Folder (⇧⌘N), “Open With”
- [ ] A notice for each new download
- [ ] Built-in updates (Sparkle), from 0.2.0 on: each new version downloads in the background and installs when you quit the app, without any click (can be turned off in Settings)

## Download

**[Download the latest release](https://github.com/elit28/NoyaFiles/releases/latest)**: get the `NOYA-Files-<version>.dmg` file, open it and drag **NOYA Files** to **Applications**. The app runs on macOS 14 Sonoma and later, on Apple silicon and Intel. A SHA-256 checksum is published next to each disk image.

Until the app is signed with an Apple Developer ID certificate, macOS shows a warning on first launch. To open it anyway, launch it once, then open **System Settings › Privacy & Security** and click **Open Anyway**.

To try changes that are not released yet, every automated build also produces a test disk image: open the [Actions](https://github.com/elit28/NoyaFiles/actions) tab, pick the latest successful run of the **CI** workflow, and download the **NOYA-Files-macOS** artifact (you need to be signed in to GitHub).

## Building from source

Requirements: macOS 14 Sonoma or later, and Xcode 16 or later. Built with Xcode 26, the assistant can also use Apple Intelligence on Macs running macOS 26; built with Xcode 16, it relies on local rules only.

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
| `Config/` | App settings that Xcode does not manage, such as the address and public key of updates. |
| `Packages/NoyaCore/` | Logic that does not depend on the interface (reading folders, categories, sizes, suggestions) and its tests. It also builds on Linux. |
| `scripts/` | Building, creating the `.dmg`, checking translations and, in `scripts/ci/`, the demo data and automated screenshots. |
| `.github/workflows/` | Automated builds and tests, and releases. |
| `Design/` | Design sources, including the app icon. |

## Releasing

Change the version number, then merge that change into `main`:

```bash
scripts/set-version.sh 0.2.0
```

In Xcode, it is the **Version** field of the NoyaFiles target. As soon as the new version reaches `main`, the **Release** workflow starts on its own: it builds the app, creates the `.dmg` and publishes the release in [Releases](https://github.com/elit28/NoyaFiles/releases), with nothing else to do. A version that is already published is never built again.

You can also start the workflow by hand: push a tag such as `v0.2.0`, or use **Run workflow** in the [Actions](https://github.com/elit28/NoyaFiles/actions/workflows/release.yml) tab.

For installed apps to offer the new version, the repository needs the `SPARKLE_PRIVATE_KEY` secret: it is the key that signs each update, and it must match the `SUPublicEDKey` public key in `Config/Info.plist`. The workflow then signs the `.dmg` and attaches an `appcast.xml` file to the release; the app reads it to learn that an update exists. Right after publishing, a last job installs the previous version on a test Mac and checks that it updates itself to the new one. Without that secret, the release is published without the file and only manual downloads work.

For the app to open without any warning, add these repository secrets: `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD`. This requires an Apple Developer account. The details are at the top of `.github/workflows/release.yml`.

## Technology

- Swift 6
- SwiftUI
- AppKit
- Native macOS frameworks
- [Sparkle](https://sparkle-project.org) for updates

## Privacy

Everything happens on your Mac: no account, no analytics, no file ever sent over the internet. The one exception, if you leave it on: once a day, the app asks GitHub whether a new version exists, without sending anything about your Mac or your files (Settings › General › Updates). The AI assistant is off by default; once turned on, it handles your requests and files on the Mac (with Apple Intelligence when available), proposes a plan and changes nothing without your agreement.

## Contributing

Contributions, bug reports and feature suggestions are welcome.

## License

NOYA Files is licensed under the [GNU General Public License v3.0 or later](LICENSE).

## Credits

Developed by NOYA 360.

NOYA Files is an independent project and is not affiliated with FileOS or Apple.
