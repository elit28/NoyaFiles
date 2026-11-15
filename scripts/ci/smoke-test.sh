#!/usr/bin/env bash
# Launches the built app on a sample folder, checks that it keeps running,
# and takes screenshots in light and dark mode.
#
# Screenshots land in dist/screenshots.
#
# On CI (CI=true), it also writes a few demo invoices to the home folder for the
# assistant to find. Run elsewhere, it leaves your own Downloads and Documents alone.
set -euo pipefail

cd "$(dirname "$0")/../.."

binary="dist/NOYA Files.app/Contents/MacOS/NOYA Files"
[[ -x "$binary" ]] || { echo "error: $binary not found. Run scripts/build-app.sh first." >&2; exit 1; }

demo="$(mktemp -d)/Downloads"
scripts/ci/make-demo-folder.sh "$demo"
projects="$(dirname "$demo")/Developer"
scripts/ci/make-demo-projects.sh "$projects"
if [[ "${CI:-}" == "true" ]]; then
  python3 scripts/ci/make-demo-invoices.py "$HOME"
  # Asks Spotlight to index them now rather than in a few minutes.
  find "$HOME/Downloads" "$HOME/Documents/Administratif" -name "*.pdf" -exec mdimport {} \; 2>/dev/null || true
fi
mkdir -p dist/screenshots

# The appearance argument is the app's own View › Appearance setting.
# Every run but the welcome one skips the first-launch steps.
run() {
  local name="$1" appearance="$2"; shift 2
  local onboarding=YES
  [[ "$name" == welcome* ]] && onboarding=NO
  "$binary" "$@" -appearance "$appearance" -browser.lastPath "$demo" -browser.insightsVisible YES \
    -onboarding.completed "$onboarding" -ApplePersistenceIgnoreState YES > "dist/screenshots/$name.log" 2>&1 &
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

run welcome-light light -AppleLanguages "(fr)"
run grid-light light -browser.viewMode grid -browser.grouping kind -AppleLanguages "(en)"
run grid-dark dark -browser.viewMode grid -browser.grouping kind -AppleLanguages "(fr)"
run list-dark dark -browser.viewMode list -browser.grouping kind -AppleLanguages "(en)"
run columns-dark dark -browser.viewMode columns -AppleLanguages "(fr)"
run dualpane-light light -window.dualPane YES -AppleLanguages "(fr)"
run space-dark dark -noya.startDestination freeUpSpace -AppleLanguages "(fr)"
run tidy-light light -noya.showTidy YES -AppleLanguages "(fr)"
run search-light light -noya.startDestination search -AppleLanguages "(fr)"
run developer-dark dark -noya.startDestination developer -developer.root "$projects" -AppleLanguages "(fr)"
run assistant-light light -noya.startDestination assistant -assistant.enabled YES -developer.root "$projects" \
  -noya.assistantPrompt "Trouve mes factures de 2026 et range-les dans l'espace Impôts 2026" -AppleLanguages "(fr)"
