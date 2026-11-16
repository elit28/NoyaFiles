#!/usr/bin/env bash
# Checks that macOS will let the app load its frameworks.
#
# With the hardened runtime, macOS only loads frameworks signed by the same team as the app
# (library validation). A mismatch stops the app at launch with "mapping process and mapped
# file have different Team IDs". Some test machines do not enforce it, so this checks the
# signatures themselves.
#
# Usage: scripts/ci/check-library-validation.sh "dist/NOYA Files.app"
set -euo pipefail

app="${1:?usage: check-library-validation.sh <app>}"
main="$app/Contents/MacOS/$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$app/Contents/Info.plist")"

signature() { codesign -dv --verbose=4 "$1" 2>&1; }
team_of() { signature "$1" | sed -n 's/^TeamIdentifier=//p'; }

main_signature="$(signature "$main")"
main_team="$(team_of "$main")"
flags="$(sed -n 's/^CodeDirectory.*flags=\(0x[0-9a-f]*([^)]*)\).*/\1/p' <<<"$main_signature" | head -n 1)"
echo "App: team ${main_team:-none}, flags $flags"

if [[ "$flags" != *runtime* ]]; then
  echo "No hardened runtime: macOS does not check the frameworks' teams."
  exit 0
fi
if codesign -d --entitlements - --xml "$main" 2>/dev/null | grep -q "com.apple.security.cs.disable-library-validation"; then
  echo "Library validation is turned off by an entitlement."
  exit 0
fi

status=0
for framework in "$app"/Contents/Frameworks/*.framework "$app"/Contents/Frameworks/*.dylib; do
  [[ -e "$framework" ]] || continue
  binary="$framework"
  if [[ -d "$framework" ]]; then
    binary="$framework/$(basename "$framework" .framework)"
  fi
  team="$(team_of "$binary")"
  if [[ "$team" == "$main_team" ]]; then
    echo "$(basename "$framework"): team ${team:-none}, same as the app."
  else
    echo "error: $(basename "$framework") is signed by team ${team:-none}, the app by ${main_team:-none}. With the hardened runtime, macOS will refuse to load it and the app will not start." >&2
    status=1
  fi
done
exit "$status"
