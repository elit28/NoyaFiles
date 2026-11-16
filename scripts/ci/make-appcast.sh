#!/usr/bin/env bash
# Signs the disk image of a release and writes dist/appcast.xml, the feed Sparkle reads
# to offer the new version inside installed apps.
#
# The Release workflow attaches appcast.xml to the GitHub release, and the app reads it at
# https://github.com/<repo>/releases/latest/download/appcast.xml (SUFeedURL).
#
# Usage:
#   SPARKLE_PRIVATE_KEY=<key> scripts/ci/make-appcast.sh <version>
#   scripts/ci/make-appcast.sh --self-test    signs with a throwaway key, to test the steps in CI
set -euo pipefail

cd "$(dirname "$0")/../.."

app="dist/NOYA Files.app"
plist="$app/Contents/Info.plist"
[[ -f "$plist" ]] || { echo "error: $plist not found. Run scripts/build-app.sh first." >&2; exit 1; }

info() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
short_version="$(info CFBundleShortVersionString)"
build="$(info CFBundleVersion)"
minimum="$(info LSMinimumSystemVersion 2>/dev/null || echo 14.0)"
public_key="$(info SUPublicEDKey)"

dmg="$(ls dist/*.dmg 2>/dev/null | head -n 1)"
[[ -n "$dmg" ]] || { echo "error: no disk image in dist. Run scripts/make-dmg.sh first." >&2; exit 1; }

if [[ "${1:-}" == "--self-test" ]]; then
  read -r test_key test_public < <(xcrun swift scripts/ci/ed25519-sign.swift --generate)
  export SPARKLE_PRIVATE_KEY="$test_key"
  public_key="$test_public"
  output="dist/appcast-self-test.xml"
else
  version="${1:?usage: make-appcast.sh <version> | --self-test}"
  if [[ "$version" != "$short_version" ]]; then
    echo "error: the app says it is version $short_version, not $version." >&2
    exit 1
  fi
  output="dist/appcast.xml"
fi

signature="$(xcrun swift scripts/ci/ed25519-sign.swift "$dmg" "$public_key")"
length="$(stat -f%z "$dmg")"
name="$(basename "$dmg")"
repository="${GITHUB_REPOSITORY:-elit28/NoyaFiles}"
tag="v$short_version"
date="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")"

cat > "$output" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>NOYA Files</title>
    <link>https://github.com/$repository</link>
    <item>
      <title>NOYA Files $short_version</title>
      <pubDate>$date</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$short_version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$minimum</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/$repository/releases/tag/$tag</sparkle:fullReleaseNotesLink>
      <enclosure url="https://github.com/$repository/releases/download/$tag/$name" length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
    </item>
  </channel>
</rss>
XML

xmllint --noout "$output"
echo "Wrote $output: $name, $length bytes, build $build, signed."
