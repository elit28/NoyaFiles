#!/usr/bin/env bash
# Packages dist/NOYA Files.app into a disk image users can download.
#
# The image opens on the app next to a shortcut to the Applications folder,
# so installing is a single drag. It lands in dist/NOYA-Files-<version>.dmg,
# next to a .sha256 checksum file.
#
# Optional environment variables:
#   DEVELOPER_ID_APPLICATION       Signs the disk image with this identity.
#   APPLE_ID, APPLE_TEAM_ID,
#   APPLE_APP_SPECIFIC_PASSWORD    Notarizes the disk image with Apple and staples
#                                  the ticket, so it opens without any warning.
set -euo pipefail

cd "$(dirname "$0")/.."

app="dist/NOYA Files.app"
[[ -d "$app" ]] || { echo "error: $app not found. Run scripts/build-app.sh first." >&2; exit 1; }

version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")"
dmg="dist/NOYA-Files-$version.dmg"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/NOYA Files.app"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
# hdiutil sometimes fails with "Resource busy" on CI machines; a retry is enough.
for attempt in 1 2 3; do
  if hdiutil create -volname "NOYA Files" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"; then
    break
  fi
  [[ $attempt -eq 3 ]] && { echo "error: hdiutil failed 3 times" >&2; exit 1; }
  sleep 5
done

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$dmg"
fi

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" && -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  echo "Notarizing $dmg…"
  xcrun notarytool submit "$dmg" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
  xcrun stapler staple "$dmg"
else
  echo "Notarization skipped: the disk image will show a Gatekeeper warning on other Macs."
fi

(cd dist && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")
echo "Created $dmg"
