#!/usr/bin/env bash
# Packages dist/NOYA Files.app into a disk image users can download.
#
# The image opens on a window that shows the app next to a shortcut to the Applications
# folder, over a background that says to drag one onto the other (Design/dmg).
# It lands in dist/NOYA-Files-<version>.dmg, next to a .sha256 checksum file.
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

# dmgbuild lays out the window: background, icon positions and volume icon. It is installed
# in build/dmgbuild when missing; without network, a plain disk image is made instead.
dmgbuild=""
if command -v dmgbuild >/dev/null 2>&1; then
  dmgbuild="dmgbuild"
elif [[ -x build/dmgbuild/bin/dmgbuild ]] || { python3 -m venv build/dmgbuild >/dev/null 2>&1 \
    && build/dmgbuild/bin/pip install --quiet "dmgbuild==2.0.0" >/dev/null 2>&1; }; then
  dmgbuild="build/dmgbuild/bin/dmgbuild"
fi

rm -f "$dmg"
# hdiutil sometimes fails with "Resource busy" on CI machines; a retry is enough.
for attempt in 1 2 3; do
  if [[ -n "$dmgbuild" ]]; then
    if "$dmgbuild" -s Design/dmg/settings.py \
        -D app="$app" \
        -D background=Design/dmg/background.png \
        -D icon="$app/Contents/Resources/AppIcon.icns" \
        "NOYA Files" "$dmg"; then
      break
    fi
  else
    echo "warning: dmgbuild is not available, so the disk image has no background." >&2
    staging="$(mktemp -d)"
    ditto "$app" "$staging/NOYA Files.app"
    ln -s /Applications "$staging/Applications"
    if hdiutil create -volname "NOYA Files" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"; then
      rm -rf "$staging"
      break
    fi
    rm -rf "$staging"
  fi
  [[ $attempt -eq 3 ]] && { echo "error: the disk image could not be created after 3 attempts" >&2; exit 1; }
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
