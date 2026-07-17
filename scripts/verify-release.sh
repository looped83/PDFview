#!/usr/bin/env bash
#
# verify-release.sh — sanity-checks the built dist/PDF Viewer.app (and dist/PDFViewer.dmg,
# if present): bundle structure, code signature, Gatekeeper assessment, and notarization
# staple. Safe to run at any point in the release pipeline — checks that don't apply yet
# (e.g. stapler validation before notarization) are reported, not treated as fatal.
#
# Usage:
#   scripts/verify-release.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_PATH="${ROOT_DIR}/dist/PDF Viewer.app"
DMG_PATH="${ROOT_DIR}/dist/PDFViewer.dmg"

PASS=0
FAIL=0

ok() { printf '  \033[1;32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[1;31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
info() { printf '  \033[2m·\033[0m %s\n' "$1"; }
section() { printf '\n\033[1;34m%s\033[0m\n' "$1"; }

section "Bundle structure"
if [ -d "${APP_PATH}" ]; then
  ok "dist/PDF Viewer.app exists"
  [ -f "${APP_PATH}/Contents/Info.plist" ] && ok "Info.plist present" || bad "Info.plist missing"
  [ -x "${APP_PATH}/Contents/MacOS/PDFViewer" ] && ok "Executable present and executable" || bad "Executable missing or not executable"
else
  bad "dist/PDF Viewer.app not found — run scripts/build-release.sh first."
fi

section "Code signature"
if [ -d "${APP_PATH}" ]; then
  if codesign --verify --deep --strict --verbose=2 "${APP_PATH}" 2>&1 | tee /tmp/pdfviewer-codesign.log >/dev/null; then
    ok "codesign --verify --deep --strict passed"
  else
    bad "codesign verification failed (see /tmp/pdfviewer-codesign.log)"
  fi

  SIGN_INFO="$(codesign --display --verbose=2 "${APP_PATH}" 2>&1 || true)"
  if printf '%s' "${SIGN_INFO}" | grep -q "Signature=adhoc"; then
    info "Signature is ad hoc (local development build — expected unless you ran scripts/sign-app.sh)"
  elif printf '%s' "${SIGN_INFO}" | grep -q "Authority=Developer ID Application"; then
    ok "Signed with a Developer ID Application identity"
  else
    info "Signature identity could not be classified automatically — inspect manually if distributing."
  fi
fi

section "Gatekeeper assessment (spctl)"
if [ -d "${APP_PATH}" ]; then
  if command -v spctl >/dev/null 2>&1; then
    if spctl --assess --type execute --verbose "${APP_PATH}" 2>&1 | tee /tmp/pdfviewer-spctl.log >/dev/null; then
      ok "spctl accepts the app"
    else
      info "spctl rejected the app — expected for unsigned/ad hoc local builds; required to pass before distribution (see /tmp/pdfviewer-spctl.log)."
    fi
  else
    info "spctl not available — skipping."
  fi
fi

section "Notarization staple"
if [ -d "${APP_PATH}" ]; then
  if command -v xcrun >/dev/null 2>&1; then
    if xcrun stapler validate "${APP_PATH}" >/tmp/pdfviewer-stapler.log 2>&1; then
      ok "Notarization ticket is stapled and valid"
    else
      info "No valid staple found — expected until scripts/notarize-app.sh has been run."
    fi
  fi
fi

section "DMG"
if [ -f "${DMG_PATH}" ]; then
  ok "dist/PDFViewer.dmg exists"
  if hdiutil verify "${DMG_PATH}" >/dev/null 2>&1; then
    ok "hdiutil verify passed"
  else
    bad "hdiutil verify failed"
  fi
else
  info "dist/PDFViewer.dmg not found — run scripts/create-dmg.sh if you need one."
fi

section "Summary"
printf '  %d passed, %d failed\n' "${PASS}" "${FAIL}"

if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
