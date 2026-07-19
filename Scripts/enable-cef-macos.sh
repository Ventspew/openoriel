#!/usr/bin/env bash
# Local Mac helper: fetch CEF (if needed) and build Oriel Engine artifacts + xcconfig.
# Prefer: bash Scripts/build-oriel-engine-macos.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/Scripts/build-oriel-engine-macos.sh"

cat <<EOF

Oriel Engine enabled for local Mac builds.

In Xcode (Mac destination):
  1. Apply Vendor/CEF.xcconfig as the configuration file for Debug/Release, or
     set the same ORIEL_HAS_CEF / HEADER_SEARCH_PATHS / LIBRARY_SEARCH_PATHS flags.
  2. Use Resources/Oriel-macOS-Engine.entitlements (App Sandbox off) for Mac Engine runs.
  3. After Build, run:
       bash Scripts/embed-oriel-engine-macos.sh DerivedData/.../Oriel.app
     or use Scripts/make-macos-dmg.sh which does fetch → build → embed.

Honesty: iPhone/iPad stay WebKit-only. Oriel Engine is Mac-only Blink (CEF).
EOF
