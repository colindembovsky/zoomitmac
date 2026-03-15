#!/usr/bin/env bash

set -euo pipefail

BUNDLE_ID="com.colindembovsky.ZoomItMac"

echo "Resetting Screen Recording permission for ${BUNDLE_ID}..."
tccutil reset ScreenCapture "${BUNDLE_ID}"

cat <<'EOF'
Screen Recording permission has been reset for ZoomItMac.

Next steps:
1. Start the already-built app with: ./scripts/run-app.sh
2. When macOS prompts or opens System Settings, enable ZoomItMac in Privacy & Security > Screen Recording.
3. Quit ZoomItMac from the menu bar icon.
4. Start it again with: ./scripts/run-app.sh

Important: do not rebuild the app between steps 1 and 4.
EOF
