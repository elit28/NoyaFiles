#!/usr/bin/env bash
# Launches the built app on a sample folder, checks that it keeps running,
# and takes screenshots in light and dark mode.
#
# Screenshots land in dist/screenshots.
set -euo pipefail

cd "$(dirname "$0")/../.."

binary="dist/NOYA Files.app/Contents/MacOS/NOYA Files"
[[ -x "$binary" ]] || { echo "error: $binary not found. Run scripts/build-app.sh first." >&2; exit 1; }

demo="$(mktemp -d)/Downloads"
scripts/ci/make-demo-folder.sh "$demo"
mkdir -p dist/screenshots

run() {
  local name="$1"; shift
  "$binary" "$@" -browser.lastPath "$demo" -browser.insightsVisible YES \
    -ApplePersistenceIgnoreState YES > "dist/screenshots/$name.log" 2>&1 &
  local pid=$!
  sleep 10
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "error: the app quit during the '$name' run. Its output:" >&2
    cat "dist/screenshots/$name.log" >&2
    exit 1
  fi
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" 2>/dev/null || true
  sleep 1
  screencapture -x "dist/screenshots/$name.png" || echo "warning: could not take the '$name' screenshot"
  kill "$pid"
  wait "$pid" 2>/dev/null || true
  echo "The app ran fine: $name"
}

run grid-light -browser.viewMode grid -browser.grouping kind -AppleLanguages "(en)"
run grid-dark -browser.viewMode grid -browser.grouping kind -AppleInterfaceStyle Dark -AppleLanguages "(fr)"
run list-dark -browser.viewMode list -browser.grouping kind -AppleInterfaceStyle Dark -AppleLanguages "(en)"
