#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURATION="${1:-debug}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

cd "${ROOT_DIR}"

# Keep stdout clean so callers can safely capture just the final app path.
swift build -c "${CONFIGURATION}" >&2

BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"
APP_DIR="${ROOT_DIR}/dist/${CONFIGURATION}/ZoomItMac.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}"

cp "${ROOT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${BIN_DIR}/ZoomItMac" "${MACOS_DIR}/ZoomItMac"
chmod +x "${MACOS_DIR}/ZoomItMac"

xcrun swift-stdlib-tool \
  --copy \
  --platform macosx \
  --scan-executable "${MACOS_DIR}/ZoomItMac" \
  --destination "${FRAMEWORKS_DIR}" >&2

if [[ -n "${CODESIGN_IDENTITY}" ]]; then
  echo "Signing app with identity: ${CODESIGN_IDENTITY}" >&2
  codesign --force --deep --sign "${CODESIGN_IDENTITY}" "${APP_DIR}" >&2
else
  echo "Signing app ad hoc. Screen Recording permission may reset after rebuilds." >&2
  echo "Set CODESIGN_IDENTITY to a stable Apple Development certificate to preserve permissions." >&2
  codesign --force --deep --sign - "${APP_DIR}" >&2
fi

echo "${APP_DIR}"
