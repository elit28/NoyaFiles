#!/usr/bin/env bash
# Imports a Developer ID certificate into a temporary keychain on a CI machine.
#
# Required environment variables:
#   MACOS_CERTIFICATE_P12        The .p12 export of the certificate and its private key, base64-encoded.
#   MACOS_CERTIFICATE_PASSWORD   The password of the .p12 file.
#
# Exports DEVELOPER_ID_APPLICATION to the following GitHub Actions steps.
set -euo pipefail

: "${MACOS_CERTIFICATE_P12:?}"
: "${MACOS_CERTIFICATE_PASSWORD:?}"
: "${RUNNER_TEMP:?}"
: "${GITHUB_ENV:?}"

keychain="$RUNNER_TEMP/signing.keychain-db"
keychain_password="$(openssl rand -base64 32)"
certificate="$RUNNER_TEMP/certificate.p12"

echo "$MACOS_CERTIFICATE_P12" | base64 --decode > "$certificate"
trap 'rm -f "$certificate"' EXIT

security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$certificate" -P "$MACOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')

identity="$(security find-identity -v -p codesigning "$keychain" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)"
[[ -n "$identity" ]] || { echo "error: no Developer ID Application identity in the certificate" >&2; exit 1; }

echo "DEVELOPER_ID_APPLICATION=$identity" >> "$GITHUB_ENV"
echo "Imported signing identity: $identity"
