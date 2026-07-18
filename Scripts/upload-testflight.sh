#!/usr/bin/env bash
# Archive Oriel and upload to App Store Connect / TestFlight.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -d "/Users/leopold/Desktop/katwijk huiselijk geweld bronnen/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Users/leopold/Desktop/katwijk huiselijk geweld bronnen/Xcode-beta.app/Contents/Developer"
fi

BUILD_NUMBER="${1:-}"
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
fi
MARKETING="$(grep -E '^\s*MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
MARKETING="${MARKETING:-1.0.0}"

echo "→ Oriel ${MARKETING} (${BUILD_NUMBER}) → TestFlight"

command -v xcodegen >/dev/null && xcodegen generate -q
mkdir -p build

ARCHIVE="build/Oriel.xcarchive"
EXPORT_DIR="build/testflight-upload"
EXPORT_PLIST="ExportOptions-TestFlight.plist"
rm -rf "$ARCHIVE" "$EXPORT_DIR"

echo "→ Archive (Release, iOS)…"
xcodebuild archive \
  -scheme Oriel \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=2PP6UH4PWA \
  CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  MARKETING_VERSION="$MARKETING" \
  2>&1 | tee build/testflight_archive.log | tail -30

test -d "$ARCHIVE"

echo "→ Export + upload to App Store Connect…"
UPLOAD_OK=0
if xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates \
  2>&1 | tee build/testflight_upload.log; then
  UPLOAD_OK=1
fi

# Fallback: API key upload when ASC_ISSUER_ID is set and export produced an IPA without upload.
IPA="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' 2>/dev/null | head -1 || true)"
if [[ "$UPLOAD_OK" -eq 0 || -z "$IPA" ]]; then
  # Re-export to local IPA if needed
  if [[ -z "$IPA" ]]; then
    cat > build/ExportOptions-ipa.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>2PP6UH4PWA</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>stripSwiftSymbols</key>
	<true/>
</dict>
</plist>
PLIST
    rm -rf "$EXPORT_DIR"
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE" \
      -exportPath "$EXPORT_DIR" \
      -exportOptionsPlist build/ExportOptions-ipa.plist \
      -allowProvisioningUpdates \
      2>&1 | tee -a build/testflight_upload.log || true
    IPA="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' 2>/dev/null | head -1 || true)"
  fi

  if [[ -n "${ASC_ISSUER_ID:-}" && -n "$IPA" ]]; then
    KEY_ID="${ASC_KEY_ID:-TXY8G26YBJ}"
    KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8}"
    if [[ ! -f "$KEY_PATH" ]]; then
      KEY_PATH="$HOME/Downloads/AuthKey_${KEY_ID}.p8"
    fi
    mkdir -p "$HOME/.appstoreconnect/private_keys"
    cp "$KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
    chmod 600 "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
    echo "→ Uploading via altool (API key ${KEY_ID})…"
    xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    UPLOAD_OK=1
  fi
fi

if [[ "$UPLOAD_OK" -ne 1 ]]; then
  echo ""
  echo "⚠️  CLI upload failed. Archive is ready for Organizer:"
  echo "   open $ARCHIVE"
  echo ""
  echo "Or set ASC_ISSUER_ID (App Store Connect → Users and Access → Integrations → Issuer ID)"
  echo "and re-run: ASC_ISSUER_ID=… bash Scripts/upload-testflight.sh $BUILD_NUMBER"
  open "$ARCHIVE" 2>/dev/null || true
  exit 1
fi

echo ""
echo "✓ Upload started. Check App Store Connect → Oriel → TestFlight in ~5–15 min."
echo "  Bundle ID: net.inveil.oriel"
echo "  Version: ${MARKETING} (${BUILD_NUMBER})"
