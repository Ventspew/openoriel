#!/usr/bin/env bash
# Build a macOS Release .app with Oriel Engine, then package installers for end users:
#   - Drag-and-drop DMG  (Open → drag Oriel to Applications)
#   - .pkg installer     (double-click → Installs into /Applications; no Terminal)
# Set ORIEL_BUNDLE_CEF=0 for a WebKit-only slim build (no Engine).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

YML_MARKETING="$(grep -E '^\s*MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
YML_BUILD="$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
# Allow CI to override from the git tag (e.g. v1.0.0-31) so artifact names match the release.
MARKETING="${ORIEL_MARKETING_VERSION:-${YML_MARKETING:-1.0.0}}"
BUILD="${ORIEL_BUILD_NUMBER:-${YML_BUILD:-1}}"
BUNDLE_CEF="${ORIEL_BUNDLE_CEF:-1}"

OUT_DIR="${ORIEL_DMG_OUT:-$ROOT/build/dmg}"
DERIVED="${ORIEL_DERIVED_DATA:-$ROOT/build/DerivedData-dmg}"
STAGE="$OUT_DIR/stage"
PKG_ROOT="$OUT_DIR/pkgroot"
VOL_NAME="Oriel"
BASE_NAME="Oriel-${MARKETING}-${BUILD}-macOS"
DMG_NAME="${BASE_NAME}.dmg"
PKG_NAME="${BASE_NAME}.pkg"
DMG_PATH="$OUT_DIR/$DMG_NAME"
PKG_PATH="$OUT_DIR/$PKG_NAME"

echo "-> Building Oriel ${MARKETING} (${BUILD}) for macOS (Oriel Engine CEF=${BUNDLE_CEF})..."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate -q
fi

rm -rf "${DERIVED}" "${OUT_DIR}"
mkdir -p "${STAGE}" "${OUT_DIR}"

XCODEBUILD_EXTRA=()
ARCH_ARGS=(ONLY_ACTIVE_ARCH=NO)

if [[ "$BUNDLE_CEF" == "1" ]]; then
  bash "$ROOT/Scripts/build-oriel-engine-macos.sh"
  # shellcheck disable=SC1091
  source "$ROOT/build/oriel-engine/env.sh"
  ENGINE_ARCH="${ORIEL_ENGINE_ARCH:-arm64}"
  ARCH_ARGS=(ONLY_ACTIVE_ARCH=YES ARCHS="$ENGINE_ARCH" EXCLUDED_ARCHS="")
  # Flags live in Vendor/CEF.xcconfig — do not expand $(SRCROOT) in bash.
  XCODEBUILD_EXTRA=(
    -xcconfig "$ORIEL_ENGINE_XCCONFIG"
    CODE_SIGN_ENTITLEMENTS="$ORIEL_ENGINE_ENTITLEMENTS"
  )
fi

# Prefer development-team signing when certificates exist (local Mac).
# On CI (no Apple certs), fall back to unsigned compile + ad-hoc codesign below.
SIGN_ARGS=(
  CODE_SIGN_STYLE=Automatic
  DEVELOPMENT_TEAM=2PP6UH4PWA
)
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development\|Developer ID"; then
  echo "note: no Apple signing identity — building unsigned, then ad-hoc codesign"
  SIGN_ARGS=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="-"
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=NO
    DEVELOPMENT_TEAM=
    PROVISIONING_PROFILE_SPECIFIER=
  )
fi

xcodebuild \
  -scheme Oriel \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  -quiet \
  "${ARCH_ARGS[@]}" \
  "${SIGN_ARGS[@]}" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  MARKETING_VERSION="$MARKETING" \
  "${XCODEBUILD_EXTRA[@]+"${XCODEBUILD_EXTRA[@]}"}" \
  build

APP="$(find "$DERIVED/Build/Products" -maxdepth 2 -type d -name 'Oriel.app' | head -1)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "error: Oriel.app not found under $DERIVED/Build/Products" >&2
  exit 1
fi

if [[ "$BUNDLE_CEF" == "1" ]]; then
  bash "$ROOT/Scripts/embed-oriel-engine-macos.sh" "$APP"
fi

# Ad-hoc re-sign so machines outside the Apple Development profile can still
# launch via Gatekeeper right-click → Open (not notarized).
ENTITLEMENTS_FILE="${ORIEL_ENGINE_ENTITLEMENTS:-$ROOT/Resources/Oriel-macOS-Engine.entitlements}"
if [[ "$BUNDLE_CEF" == "1" && -f "$ENTITLEMENTS_FILE" ]]; then
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_FILE" "$APP"
else
  codesign --force --deep --sign - "$APP"
fi

# --- Drag-and-drop DMG ---
echo "-> Staging DMG contents..."
ditto "${APP}" "${STAGE}/Oriel.app"
ln -sf /Applications "${STAGE}/Applications"
cat > "${STAGE}/How to Install.txt" <<EOF
Oriel ${MARKETING} (build ${BUILD}) — macOS

Install (no Terminal needed):
  1. Drag Oriel into Applications
  2. Open Applications → Oriel
  3. First launch: right-click Oriel → Open (Gatekeeper may warn once on unsigned builds)

This build includes Oriel Engine (Blink) for in-tab Chromium Native on Mac.
iPhone / iPad builds stay WebKit-only (Apple rule).

Website: https://openoriel.com
EOF

echo "-> Creating ${DMG_NAME}..."
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${VOL_NAME}" \
  -srcfolder "${STAGE}" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "${DMG_PATH}" >/dev/null

rm -rf "${STAGE}"

# --- .pkg installer (double-click → /Applications) ---
echo "-> Creating ${PKG_NAME}..."
rm -rf "${PKG_ROOT}"
mkdir -p "${PKG_ROOT}/Applications"
ditto "${APP}" "${PKG_ROOT}/Applications/Oriel.app"
rm -f "${PKG_PATH}"
pkgbuild \
  --root "${PKG_ROOT}" \
  --install-location / \
  --identifier net.inveil.oriel \
  --version "${MARKETING}.${BUILD}" \
  --ownership recommended \
  "${PKG_PATH}" >/dev/null
rm -rf "${PKG_ROOT}"

shasum -a 256 "${DMG_PATH}" | tee "${DMG_PATH}.sha256"
shasum -a 256 "${PKG_PATH}" | tee "${PKG_PATH}.sha256"

echo ""
echo "OK: Installers ready in ${OUT_DIR}"
echo "  DMG: ${DMG_PATH}"
echo "  PKG: ${PKG_PATH}"
if [[ "$BUNDLE_CEF" == "1" ]]; then
  echo "  Includes Oriel Engine (Blink/CEF) — end users do NOT run enable-cef scripts."
fi
echo "  Prefer PKG for one-click install into Applications."
echo "  Unsigned / ad-hoc: right-click Oriel → Open the first time (Gatekeeper)."
