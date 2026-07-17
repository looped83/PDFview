#!/usr/bin/env bash
#
# sign-app.sh — signs dist/PDF Viewer.app with a "Developer ID Application" identity and
# the Hardened Runtime, for distribution outside the Mac App Store.
#
# Required environment variable:
#   DEVELOPER_ID_APPLICATION   e.g. "Developer ID Application: Jane Doe (TEAMID1234)"
#
# Never commit a signing identity, team ID, or credentials to this repository. Export
# DEVELOPER_ID_APPLICATION in your shell, or source a local, gitignored .env file, before
# running this script.
#
# Usage:
#   export DEVELOPER_ID_APPLICATION="Developer ID Application: Jane Doe (TEAMID1234)"
#   scripts/sign-app.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_PATH="${ROOT_DIR}/dist/PDF Viewer.app"
ENTITLEMENTS="${ROOT_DIR}/PDFViewer/Resources/PDFViewer.entitlements"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

command -v codesign >/dev/null 2>&1 || fail "codesign not found — this script must run on macOS."
[ -n "${DEVELOPER_ID_APPLICATION:-}" ] || fail "DEVELOPER_ID_APPLICATION is not set. See the header of this script."
[ -d "${APP_PATH}" ] || fail "dist/PDF Viewer.app not found. Run scripts/build-release.sh first."
[ -f "${ENTITLEMENTS}" ] || fail "Entitlements file not found at ${ENTITLEMENTS}."

# --deep is generally discouraged in favor of signing nested components individually,
# but PDF Viewer.app embeds no third-party frameworks or plugins — only its own single
# executable — so there is nothing nested for --deep to sign incorrectly here.
log "Signing PDF Viewer.app (Hardened Runtime, entitlements, secure timestamp)"
codesign --force --deep --options runtime \
  --entitlements "${ENTITLEMENTS}" \
  --sign "${DEVELOPER_ID_APPLICATION}" \
  --timestamp \
  "${APP_PATH}"

log "Verifying signature"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

log "Signed successfully. Next: scripts/notarize-app.sh"
