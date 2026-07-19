#!/usr/bin/env bash
# Embed Oriel Engine (CEF framework + Helper apps) into Oriel.app/Contents/Frameworks.
# Usage: bash Scripts/embed-oriel-engine-macos.sh /path/to/Oriel.app
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "usage: $0 /path/to/Oriel.app" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ORIEL_ENGINE_OUT:-$ROOT/build/oriel-engine}"
ENV_FILE="$OUT/env.sh"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

CEF_FW="${ORIEL_ENGINE_CEF_FRAMEWORK:-}"
HELPERS="${ORIEL_ENGINE_FRAMEWORKS:-$OUT/Frameworks}"
ENTITLEMENTS="${ORIEL_ENGINE_ENTITLEMENTS:-$ROOT/Resources/Oriel-macOS-Engine.entitlements}"

if [[ -z "$CEF_FW" || ! -d "$CEF_FW" ]]; then
  DEST="${ORIEL_CEF_DIR:-$HOME/Library/Application Support/Oriel/CEF}"
  CEF_FW="$DEST/Release/Chromium Embedded Framework.framework"
fi
if [[ ! -d "$CEF_FW" ]]; then
  echo "error: CEF framework missing at $CEF_FW" >&2
  exit 1
fi
if [[ ! -d "$HELPERS" ]]; then
  echo "error: helpers missing at $HELPERS — run Scripts/build-oriel-engine-macos.sh" >&2
  exit 1
fi

FW_ROOT="$APP/Contents/Frameworks"
FRAMEWORK_DIR="$FW_ROOT/Chromium Embedded Framework.framework"
mkdir -p "$FW_ROOT"

echo "-> Embedding Chromium Embedded Framework (versioned layout)…"
rm -rf "$FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR/Versions"
# CEF redistrib expects Versions/A + Current + top-level symlinks (Xcode 16+).
cp -R "$CEF_FW" "$FRAMEWORK_DIR/Versions/A"
(
  cd "$FRAMEWORK_DIR"
  ln -sfn "Versions/A/Chromium Embedded Framework" "Chromium Embedded Framework"
  ln -sfn "Versions/A/Libraries" "Libraries"
  ln -sfn "Versions/A/Resources" "Resources"
  cd Versions
  ln -sfn "A" "Current"
)

echo "-> Embedding Oriel Helper apps…"
for helper in "$HELPERS"/*.app; do
  [[ -d "$helper" ]] || continue
  name="$(basename "$helper")"
  rm -rf "$FW_ROOT/$name"
  cp -R "$helper" "$FW_ROOT/$name"
done

echo "-> Ad-hoc signing nested Engine binaries…"
# Sign deepest first.
find "$FRAMEWORK_DIR" -type f \( -name 'Chromium Embedded Framework' -o -name '*.dylib' \) -print0 \
  | while IFS= read -r -d '' f; do
      codesign --force --sign - --timestamp=none "$f" 2>/dev/null || codesign --force --sign - "$f"
    done
for helper in "$FW_ROOT"/Oriel\ Helper*.app; do
  [[ -d "$helper" ]] || continue
  if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --sign - --entitlements "$ENTITLEMENTS" --timestamp=none "$helper" 2>/dev/null \
      || codesign --force --sign - --entitlements "$ENTITLEMENTS" "$helper"
  else
    codesign --force --sign - "$helper"
  fi
done
if [[ -f "$ENTITLEMENTS" ]]; then
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" --timestamp=none "$APP" 2>/dev/null \
    || codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"
else
  codesign --force --deep --sign - "$APP"
fi

echo "OK: Oriel Engine embedded in $APP"
