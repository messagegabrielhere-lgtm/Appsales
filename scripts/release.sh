#!/bin/bash
# One-command App Store release from a Mac that has Xcode signed in to your Apple ID.
#
#   scripts/release.sh                     # team MAP974T827, version 1.0.0, build number from the clock
#   scripts/release.sh MAP974T827 1.0.1    # explicit marketing version
#   scripts/release.sh MAP974T827 1.0.1 42 # explicit build number
#
# Set BUNDLE_ID in the environment to override the default bundle identifier.
# Set SKIP_PAUSE=1 to skip the "create the app record" pause on later releases.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_setup.sh

TEAM_ID="${1:-MAP974T827}"
VERSION="${2:-1.0.0}"
BUILD="${3:-$(date +%Y%m%d%H%M)}"
BUNDLE_ID="${BUNDLE_ID:-com.messagegabrielhere.kept}"
ARCHIVE="build/Kept.xcarchive"
mkdir -p build

ensure_xcode
generate_project

say "Archiving $BUNDLE_ID version $VERSION build $BUILD (team $TEAM_ID)"
rm -rf "$ARCHIVE"
set +e
xcodebuild archive \
  -project Kept.xcodeproj \
  -scheme Kept \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  CODE_SIGN_STYLE=Automatic \
  > build/archive.log 2>&1
status=$?
set -e
if [ $status -ne 0 ] && grep -q "no devices" build/archive.log; then
  say "No registered device; archiving unsigned and signing at upload instead"
  rm -rf "$ARCHIVE"
  set +e
  xcodebuild archive \
    -project Kept.xcodeproj \
    -scheme Kept \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    > build/archive.log 2>&1
  status=$?
  set -e
fi
grep -E "\*\* ARCHIVE" build/archive.log || true
[ $status -eq 0 ] || show_errors_and_exit build/archive.log

cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

if [ "${SKIP_PAUSE:-}" != "1" ]; then
  cat <<MSG

The archive is signed and the bundle ID is registered with Apple.

Before uploading, the app record must exist in App Store Connect:
  https://appstoreconnect.apple.com/apps  ->  +  ->  New App
  Bundle ID: $BUNDLE_ID   SKU: kept-ios-1   Name: Kept: Daily Habit Streaks

MSG
  read -r -p "Press Enter once the app record exists (or Ctrl-C to stop here)... " _
fi

say "Uploading to App Store Connect"
set +e
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates \
  > build/export.log 2>&1
status=$?
set -e
grep -E "Upload succeeded|EXPORT SUCCEEDED" build/export.log || true
[ $status -eq 0 ] || show_errors_and_exit build/export.log

say "Done. Build $BUILD of $VERSION is uploaded. It appears under TestFlight in App Store Connect in 10 to 30 minutes."
