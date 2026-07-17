#!/usr/bin/env bash
#
# build-release.sh — clean Release build of PDF Viewer, producing dist/PDF Viewer.app.
#
# Usage:
#   scripts/build-release.sh
#
# Requires:
#   - macOS with Xcode 26 (or later) and its command line tools
#   - XcodeGen (https://github.com/yonaskolb/XcodeGen), e.g. `brew install xcodegen`,
#     to generate PDFViewer.xcodeproj from project.yml
#
# This script only ever produces a locally-runnable, unsigned or ad-hoc-signed build.
# See scripts/sign-app.sh and scripts/notarize-app.sh for Developer ID distribution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
DIST_DIR="${ROOT_DIR}/dist"
SCHEME="PDFViewer"
CONFIGURATION="Release"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

cd "${ROOT_DIR}"

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild not found — install Xcode and its command line tools."

if ! command -v xcodegen >/dev/null 2>&1; then
  fail "xcodegen not found. Install it with 'brew install xcodegen', then re-run this script."
fi

log "Generating Xcode project from project.yml"
xcodegen generate --spec "${ROOT_DIR}/project.yml" || fail "xcodegen generate failed."

[ -d "${ROOT_DIR}/PDFViewer.xcodeproj" ] || fail "PDFViewer.xcodeproj was not generated."

log "Removing previous build artifacts"
rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

log "Building ${SCHEME} (${CONFIGURATION})"
XCODEBUILD_ARGS=(
  -project "${ROOT_DIR}/PDFViewer.xcodeproj"
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -derivedDataPath "${BUILD_DIR}"
  -destination "generic/platform=macOS"
  ONLY_ACTIVE_ARCH=NO
  clean build
)

# pipefail (set above) ensures xcodebuild's exit code — not xcbeautify's — determines
# whether this step is considered a failure, whichever branch runs.
if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild "${XCODEBUILD_ARGS[@]}" | xcbeautify
else
  xcodebuild "${XCODEBUILD_ARGS[@]}"
fi

APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/PDF Viewer.app"

[ -d "${APP_PATH}" ] || fail "Expected build product not found at ${APP_PATH}."

log "Copying PDF Viewer.app to ${DIST_DIR}"
cp -R "${APP_PATH}" "${DIST_DIR}/PDF Viewer.app"

log "Build succeeded: ${DIST_DIR}/PDF Viewer.app"
