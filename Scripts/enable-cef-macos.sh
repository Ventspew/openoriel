#!/usr/bin/env bash
# Local Mac helper: fetch CEF (if needed) and build Oriel Engine artifacts + xcconfig.
# Prefer: bash Scripts/build-oriel-engine-macos.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/Scripts/build-oriel-engine-macos.sh"

cat <<EOF

Oriel Engine ready for local Mac Xcode builds.

project.yml already enables ORIEL_HAS_CEF + Engine entitlements on macosx,
and runs Scripts/xcode-embed-oriel-engine.sh after each Mac build.

One-time on this machine (already done if you just ran this script):
  bash Scripts/enable-cef-macos.sh

Then open Oriel.xcodeproj and build for My Mac — Frameworks/ will contain
Chromium Embedded Framework + Oriel Helper*.app.

Honesty: iPhone/iPad stay WebKit-only. Oriel Engine is Mac-only Blink (CEF).
EOF
