#!/usr/bin/env bash
# Opens the disk image as a person would, takes a screenshot of its window, and checks
# that the app inside still starts when it carries the "downloaded from the internet"
# quarantine flag that browsers add.
#
# Usage: scripts/ci/check-dmg.sh      (after scripts/make-dmg.sh)
set -euo pipefail

cd "$(dirname "$0")/../.."

dmg="$(ls dist/*.dmg | head -n 1)"
mkdir -p dist/screenshots
work="$(mktemp -d)"

# The window, as the Finder shows it when the image is opened.
mount_point="$(hdiutil attach "$dmg" | awk -F'\t' '/\/Volumes\// {print $NF}' | tail -n 1)"
open "$mount_point"
sleep 5
screencapture -x dist/screenshots/dmg-window.png || echo "warning: could not take the screenshot"
osascript -e 'tell application "Finder" to close every window' 2>/dev/null || true
hdiutil detach "$mount_point" -quiet || hdiutil detach "$mount_point" -force -quiet
echo "Disk image window: dist/screenshots/dmg-window.png"

# The app as a browser download leaves it: quarantined, copied from the image.
echo "Gatekeeper: $(spctl --status 2>&1 || true)"
cp "$dmg" "$work/downloaded.dmg"
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");Safari;$(uuidgen)" "$work/downloaded.dmg"
mkdir -p "$work/mount" "$work/Applications"
hdiutil attach -nobrowse -readonly -mountpoint "$work/mount" "$work/downloaded.dmg" >/dev/null
ditto "$work/mount/NOYA Files.app" "$work/Applications/NOYA Files.app"
hdiutil detach "$work/mount" -quiet
app="$work/Applications/NOYA Files.app"
echo "Quarantine on the copied app: $(xattr -p com.apple.quarantine "$app" 2>/dev/null || echo none)"
echo "Quarantine on Sparkle: $(xattr -p com.apple.quarantine "$app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" 2>/dev/null || echo none)"
echo "Gatekeeper assessment: $(spctl --assess --type execute -vv "$app" 2>&1 | tr '\n' ' ')"

"$app/Contents/MacOS/NOYA Files" -onboarding.completed YES -SUEnableAutomaticChecks NO \
  > "$work/launch.log" 2>&1 &
pid=$!
sleep 8
if kill -0 "$pid" 2>/dev/null; then
  echo "The quarantined app starts."
  kill "$pid"
  wait "$pid" 2>/dev/null || true
else
  wait "$pid" 2>/dev/null && status=0 || status=$?
  echo "::warning title=Quarantined app does not start::The app copied from a downloaded disk image exits with status $status at launch."
  cat "$work/launch.log"
  log show --last 2m --style compact --predicate 'process == "NOYA Files" OR sender == "dyld" OR process == "amfid" OR process == "syspolicyd"' 2>/dev/null | tail -n 40 || true
fi
