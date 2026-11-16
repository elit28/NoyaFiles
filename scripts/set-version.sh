#!/usr/bin/env bash
# Sets the version shown to users, such as 0.2.0, in the Xcode project.
#
# Once this change reaches main, the Release workflow builds that version on its own
# and prepares a draft release.
#
# Usage: scripts/set-version.sh 0.2.0
set -euo pipefail

version="${1:?usage: scripts/set-version.sh <version, such as 0.2.0>}"
version="${version#v}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
  echo "error: '$version' is not a version such as 1.2.3" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
project="NoyaFiles.xcodeproj/project.pbxproj"
sed -i.bak "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $version;/" "$project"
rm -f "$project.bak"
echo "Version set to $version in $project"
