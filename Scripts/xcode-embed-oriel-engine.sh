#!/usr/bin/env bash
# Xcode Run Script phase: embed Oriel Engine into the built Mac .app.
# No-op on iOS. On Mac, requires Scripts/build-oriel-engine-macos.sh to have run.
set -euo pipefail

PLATFORM_NAME="${PLATFORM_NAME:-}"
if [[ "$PLATFORM_NAME" != "macosx" ]]; then
  exit 0
fi

ROOT="${SRCROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

APP="${TARGET_BUILD_DIR:-}/${FULL_PRODUCT_NAME:-Oriel.app}"
if [[ ! -d "$APP" ]]; then
  echo "warning: Oriel.app not found at $APP — skip Engine embed" >&2
  exit 0
fi

WRAPPER="${SRCROOT}/build/oriel-engine/libcef_dll_wrapper.a"
if [[ ! -f "$WRAPPER" ]]; then
  echo "error: Oriel Engine not built. Run: bash Scripts/enable-cef-macos.sh" >&2
  exit 1
fi

bash "$ROOT/Scripts/embed-oriel-engine-macos.sh" "$APP"
echo "note: Oriel Engine embedded into $APP"
