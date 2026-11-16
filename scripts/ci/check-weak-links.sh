#!/usr/bin/env bash
# Checks that frameworks which only exist on recent macOS versions are weak-linked.
#
# NOYA Files runs on macOS 14 and later. A framework such as FoundationModels (Apple
# Intelligence, macOS 26) must be linked weakly, or the app would not even open on older systems.
set -euo pipefail

cd "$(dirname "$0")/../.."

binary="dist/NOYA Files.app/Contents/MacOS/NOYA Files"
[[ -x "$binary" ]] || { echo "error: $binary not found. Run scripts/build-app.sh first." >&2; exit 1; }

status=0
for framework in FoundationModels; do
  commands="$(for arch in $(lipo -archs "$binary"); do
    otool -arch "$arch" -l "$binary" | awk -v name="$framework.framework" '/^ *cmd /{cmd=$2} index($0, name) && /name /{print cmd}'
  done | sort -u)"
  if [[ -z "$commands" ]]; then
    echo "$framework: not linked (built with an SDK that does not have it)."
  elif [[ "$commands" == "LC_LOAD_WEAK_DYLIB" ]]; then
    echo "$framework: weak-linked, the app opens on older macOS versions."
  else
    echo "error: $framework is linked with $commands. The app would not open on macOS versions without it." >&2
    status=1
  fi
done
exit "$status"
