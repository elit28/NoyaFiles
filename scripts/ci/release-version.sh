#!/usr/bin/env bash
# Works out which version the Release workflow builds, and whether it is a new one.
#
# - A pushed tag such as v0.2.0, or a version typed in "Run workflow", is always released.
# - A push to main releases the version set in the Xcode project (MARKETING_VERSION),
#   but only when no tag and no release, draft or published, exist for it yet.
#
# Writes version=… and release=true|false to $GITHUB_OUTPUT, or prints them.
set -euo pipefail

cd "$(dirname "$0")/../.."

project_version() {
  local versions
  versions="$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \([^;]*\);/\1/p' NoyaFiles.xcodeproj/project.pbxproj | sort -u)"
  if [[ "$(printf '%s\n' "$versions" | grep -c .)" != 1 ]]; then
    echo "error: the Debug and Release versions of the project differ: $(echo $versions)" >&2
    exit 1
  fi
  printf '%s' "$versions"
}

event="${GITHUB_EVENT_NAME:-push}"
ref="${GITHUB_REF:-}"
if [[ "$event" == "workflow_dispatch" ]]; then
  version="${INPUT_VERSION:?a version is required}"
  version="${version#v}"
  forced=true
elif [[ "$ref" == refs/tags/v* ]]; then
  version="${ref#refs/tags/v}"
  forced=true
else
  version="$(project_version)"
  forced=false
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
  echo "error: '$version' is not a version such as 1.2.3" >&2
  exit 1
fi

release=true
reason="Version $version will be built and prepared as a draft release."
if [[ "$forced" == false ]]; then
  if git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null 2>&1; then
    release=false
    reason="Version $version already has the tag v$version: nothing to release."
  elif gh api "repos/${GITHUB_REPOSITORY:?}/releases" --paginate --jq '.[].tag_name' | grep -qx "v$version"; then
    release=false
    reason="A release of version $version already exists, maybe as a draft: nothing to release."
  fi
fi

echo "$reason"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  echo "$reason" >> "$GITHUB_STEP_SUMMARY"
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$version"
    echo "release=$release"
  } >> "$GITHUB_OUTPUT"
else
  echo "version=$version"
  echo "release=$release"
fi
