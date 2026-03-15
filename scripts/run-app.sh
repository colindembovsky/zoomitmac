#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP_PATH="${ROOT_DIR}/dist/${CONFIGURATION}/ZoomItMac.app"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle was not found at: ${APP_PATH}" >&2
  echo "Build it first with: ./scripts/build-app.sh ${CONFIGURATION}" >&2
  exit 1
fi

open "${APP_PATH}"
