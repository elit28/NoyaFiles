#!/usr/bin/env bash
# Builds NOYA Files.app as a universal (Apple silicon + Intel) Release build.
#
# The app lands in dist/NOYA Files.app.
#
# Optional environment variables:
#   MARKETING_VERSION          Version shown to users, such as 1.2.0.
#   BUILD_NUMBER               Build number, such as the CI run number.
#   DEVELOPER_ID_APPLICATION   Name of a "Developer ID Application" signing identity in the keychain.
#                              Without it the app is signed ad hoc, which is enough to run it
#                              locally but shows a Gatekeeper warning on other Macs.
#   APPLE_TEAM_ID              Team of the signing identity. Required with DEVELOPER_ID_APPLICATION.
set -euo pipefail

cd "$(dirname "$0")/.."

configuration="Release"
derived_data="build/DerivedData"
app_name="NOYA Files.app"

args=(
  -project NoyaFiles.xcodeproj
  -scheme NoyaFiles
  -configuration "$configuration"
  -derivedDataPath "$derived_data"
  -destination "generic/platform=macOS"
  ONLY_ACTIVE_ARCH=NO
)

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required when signing with a Developer ID}"
  echo "Signing with: $DEVELOPER_ID_APPLICATION"
  args+=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION"
    "DEVELOPMENT_TEAM=$APPLE_TEAM_ID"
    "OTHER_CODE_SIGN_FLAGS=--timestamp"
  )
else
  echo "No Developer ID identity given: signing ad hoc."
  args+=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=-" "DEVELOPMENT_TEAM=")
fi

[[ -n "${MARKETING_VERSION:-}" ]] && args+=("MARKETING_VERSION=$MARKETING_VERSION")
[[ -n "${BUILD_NUMBER:-}" ]] && args+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")

if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild "${args[@]}" build | xcbeautify --renderer github-actions
else
  xcodebuild "${args[@]}" build
fi

mkdir -p dist
rm -rf "dist/$app_name"
ditto "$derived_data/Build/Products/$configuration/$app_name" "dist/$app_name"

codesign --verify --deep --strict --verbose=2 "dist/$app_name"
echo "Architectures: $(lipo -archs "dist/$app_name/Contents/MacOS/NOYA Files")"
echo "Built dist/$app_name"
