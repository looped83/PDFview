#!/usr/bin/env bash
#
# notarize-app.sh — submits the signed dist/PDF Viewer.app to Apple's notary service and
# staples the resulting ticket, so Gatekeeper can verify it offline.
#
# Required environment variable:
#   NOTARY_KEYCHAIN_PROFILE   name of a keychain profile created ahead of time via:
#     xcrun notarytool store-credentials "<profile-name>" \
#       --apple-id "you@example.com" \
#       --team-id "TEAMID1234" \
#       --password "app-specific-password"
#
# This keeps Apple ID credentials and app-specific passwords out of this repository and
# out of your shell history entirely — they live only in the local keychain.
#
# Usage:
#   export NOTARY_KEYCHAIN_PROFILE="pdfviewer-notary"
#   scripts/notarize-app.sh
#
# Requires scripts/sign-app.sh to have been run first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_PATH="${ROOT_DIR}/dist/PDF Viewer.app"
ZIP_PATH="${ROOT_DIR}/dist/PDFViewer-notarize.zip"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

command -v xcrun >/dev/null 2>&1 || fail "xcrun not found — this script must run on macOS with Xcode command line tools."
[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ] || fail "NOTARY_KEYCHAIN_PROFILE is not set. See the header of this script."
[ -d "${APP_PATH}" ] || fail "dist/PDF Viewer.app not found. Run scripts/build-release.sh and scripts/sign-app.sh first."

codesign --verify --strict "${APP_PATH}" 2>/dev/null \
  || fail "PDF Viewer.app is not properly signed. Run scripts/sign-app.sh first."

log "Archiving app for submission"
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

log "Submitting to Apple's notary service (this can take a few minutes)"
xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_KEYCHAIN_PROFILE}" --wait

log "Stapling notarization ticket to PDF Viewer.app"
xcrun stapler staple "${APP_PATH}"

log "Validating staple"
xcrun stapler validate "${APP_PATH}"

rm -f "${ZIP_PATH}"

log "Notarization complete. Re-run scripts/create-dmg.sh now if you need a DMG containing the stapled app."
