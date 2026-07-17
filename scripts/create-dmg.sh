#!/usr/bin/env bash
#
# create-dmg.sh — packages dist/PDFViewer.app into an installable dist/PDFViewer.dmg
# containing the app and a symlink to /Applications, with a simple Finder layout.
#
# Uses only macOS built-in tools (hdiutil, osascript, iconutil/sips) — no third-party
# DMG-creation utility is required.
#
# Usage:
#   scripts/create-dmg.sh
#
# Requires dist/PDFViewer.app to already exist (run scripts/build-release.sh first).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${DIST_DIR}/PDFViewer.app"
VOLUME_NAME="PDF Viewer"
DMG_PATH="${DIST_DIR}/PDFViewer.dmg"
STAGING_DIR="$(mktemp -d /tmp/pdfviewer-dmg-staging.XXXXXX)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }
cleanup() { rm -rf "${STAGING_DIR}"; }
trap cleanup EXIT

command -v hdiutil >/dev/null 2>&1 || fail "hdiutil not found — this script must run on macOS."
[ -d "${APP_PATH}" ] || fail "dist/PDFViewer.app not found. Run scripts/build-release.sh first."

rm -f "${DMG_PATH}"

log "Staging DMG contents"
cp -R "${APP_PATH}" "${STAGING_DIR}/PDFViewer.app"
ln -s /Applications "${STAGING_DIR}/Applications"

# Optional custom volume icon, derived from the app's own icon if available.
ICONSET_SOURCE="${ROOT_DIR}/PDFViewer/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if [ -f "${ICONSET_SOURCE}" ] && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  log "Building volume icon"
  ICONSET_DIR="$(mktemp -d /tmp/pdfviewer-iconset.XXXXXX)"
  mkdir -p "${ICONSET_DIR}/VolumeIcon.iconset"
  for size in 16 32 128 256 512; do
    sips -z "${size}" "${size}" "${ICONSET_SOURCE}" \
      --out "${ICONSET_DIR}/VolumeIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "${double}" "${double}" "${ICONSET_SOURCE}" \
      --out "${ICONSET_DIR}/VolumeIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "${ICONSET_DIR}/VolumeIcon.iconset" -o "${STAGING_DIR}/.VolumeIcon.icns" \
    || log "Volume icon generation failed — continuing without a custom icon."
  rm -rf "${ICONSET_DIR}"
  if [ -f "${STAGING_DIR}/.VolumeIcon.icns" ]; then
    SetFile -a C "${STAGING_DIR}" 2>/dev/null || true
  fi
fi

log "Creating disk image"
TEMP_DMG="${STAGING_DIR}/temp.dmg"
hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "${TEMP_DMG}" >/dev/null

log "Mounting disk image to arrange Finder layout"
MOUNT_OUTPUT="$(hdiutil attach "${TEMP_DMG}" -readwrite -noverify -noautoopen)"
DEVICE="$(printf '%s' "${MOUNT_OUTPUT}" | awk '/\/dev\/disk/ {print $1; exit}')"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

if [ -d "${MOUNT_POINT}" ] && command -v osascript >/dev/null 2>&1; then
  osascript >/dev/null <<APPLESCRIPT || log "Finder layout customization failed — continuing with default layout."
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "PDFViewer.app" of container window to {140, 180}
        set position of item "Applications" of container window to {420, 180}
        close
    end tell
end tell
APPLESCRIPT
  sync
fi

log "Detaching disk image"
hdiutil detach "${DEVICE}" -force >/dev/null 2>&1 || true

log "Converting to compressed, read-only disk image"
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -ov -o "${DMG_PATH}" >/dev/null

[ -f "${DMG_PATH}" ] || fail "DMG was not created."

log "Created ${DMG_PATH}"
