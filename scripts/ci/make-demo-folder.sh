#!/usr/bin/env bash
# Fills a folder with a realistic mix of downloads, for screenshots and smoke tests.
# Usage: scripts/ci/make-demo-folder.sh <folder>
set -euo pipefail

root="${1:?usage: make-demo-folder.sh <folder>}"
mkdir -p "$root"
cd "$root"

# Writes a file of the given size in kilobytes.
file() { mkdir -p "$(dirname "$1")"; head -c "$(( $2 * 1024 ))" /dev/zero > "$1"; }

# Real images, so Quick Look has something to preview.
icon() {
  local source
  source="$( (ls /System/Applications/"$1".app/Contents/Resources/*.icns 2>/dev/null || true) | head -n 1)"
  [[ -n "$source" ]] && sips -s format png -Z 512 "$source" --out "$2" >/dev/null 2>&1 || file "$2" 300
}
icon Calculator "Holiday photo.png"
icon Calendar "Team offsite.png"
icon Notes "Moodboard.png"
icon Calculator "Screenshot 2026-11-14 at 10.12.03.png"
icon Calendar "Screenshot 2026-11-13 at 18.40.51.png"

file "Quarterly report.pdf" 1800
file "Invoice 2026-118.pdf" 240
file "Product brief.docx" 96
file "Budget 2026.xlsx" 180
file "Meeting notes.md" 4
file "Conference talk.mov" 48000
file "Screen recording.mp4" 22000
file "Podcast episode 12.mp3" 9000
file "Design assets.zip" 15000
file "Sketch-101.2.dmg" 31000
file "Printer driver.pkg" 6000
file "script.py" 3
file "data.unknown" 12

file "Projects/website/index.html" 20
file "Projects/website/hero.png" 800
file "Projects/app/build.zip" 12000
file "Archive/2025/old-backup.zip" 26000
file "BrowserDownloads/setup.dmg" 18000
file ".hidden-cache" 64
