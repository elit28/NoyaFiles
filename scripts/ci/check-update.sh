#!/usr/bin/env bash
# Installs a published version of NOYA Files and checks that it updates itself, with Sparkle,
# to the version just published, without any click: Sparkle downloads it in the background
# and installs it when the app quits.
#
# Usage: scripts/ci/check-update.sh <installed version> <expected version>
#
# For CI only: it changes the app's preferences and installs the app in ~/Applications.
set -euo pipefail

from="${1:?usage: check-update.sh <installed version> <expected version>}"
to="${2:?usage: check-update.sh <installed version> <expected version>}"
repository="${GITHUB_REPOSITORY:-elit28/NoyaFiles}"
domain="com.noya360.NoyaFiles"
work="$(mktemp -d)"
app="$HOME/Applications/NOYA Files.app"

installed_version() {
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist"
}

diagnose() {
  echo "--- App output"
  cat "$work/app.log" 2>/dev/null | tail -n 40 || true
  echo "--- Sparkle messages"
  log show --last 15m --style compact \
    --predicate 'subsystem == "org.sparkle-project.Sparkle" OR process == "Autoupdate" OR process == "NOYA Files"' 2>/dev/null \
    | grep -i -E "sparkle|update|install|error" | tail -n 60 || true
  echo "--- Sparkle caches"
  find "$HOME/Library/Caches/$domain" -maxdepth 6 2>/dev/null | head -n 40 || true
}

echo "Installing NOYA Files $from in ~/Applications…"
curl -fsSL -o "$work/old.dmg" "https://github.com/$repository/releases/download/v$from/NOYA-Files-$from.dmg"
mkdir -p "$HOME/Applications" "$work/mount"
rm -rf "$app"
hdiutil attach -nobrowse -readonly -mountpoint "$work/mount" "$work/old.dmg" >/dev/null
ditto "$work/mount/NOYA Files.app" "$app"
hdiutil detach "$work/mount" -quiet
echo "Installed version: $(installed_version)"

if ! /usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$app/Contents/Info.plist" >/dev/null 2>&1; then
  echo "::notice title=Update test skipped::NOYA Files $from has no built-in updater, so there is nothing to check."
  exit 0
fi

# Like a person who left automatic updates on, and whose last check is long past.
defaults write "$domain" SUEnableAutomaticChecks -bool YES
defaults write "$domain" SUAutomaticallyUpdate -bool YES
defaults write "$domain" SUHasLaunchedBefore -bool YES
defaults write "$domain" SULastCheckTime -date "2020-01-01 00:00:00 +0000"
defaults write "$domain" onboarding.completed -bool YES

echo "Launching it: Sparkle should find $to and download it in the background…"
"$app/Contents/MacOS/NOYA Files" -ApplePersistenceIgnoreState YES > "$work/app.log" 2>&1 &
pid=$!

downloaded=false
for _ in $(seq 1 48); do
  sleep 5
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "error: the app quit on its own." >&2
    diagnose
    exit 1
  fi
  if find "$HOME/Library/Caches/$domain" -name "NOYA-Files-$to.dmg" 2>/dev/null | grep -q .; then
    downloaded=true
    break
  fi
done
if [[ "$downloaded" == true ]]; then
  echo "Sparkle downloaded NOYA-Files-$to.dmg. Giving it time to prepare the installation…"
  sleep 20
else
  echo "warning: no downloaded update found after 4 minutes; quitting anyway to see what happens." >&2
fi

echo "Quitting the app, which is when Sparkle installs the update…"
osascript -e "tell application id \"$domain\" to quit" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
for _ in $(seq 1 30); do
  kill -0 "$pid" 2>/dev/null || break
  sleep 1
done
kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true

for _ in $(seq 1 36); do
  current="$(installed_version 2>/dev/null || true)"
  if [[ "$current" == "$to" ]]; then
    echo "NOYA Files updated itself from $from to $to, without any click."
    exit 0
  fi
  sleep 5
done

echo "error: NOYA Files is still at version ${current:-unknown}, not $to." >&2
diagnose
exit 1
