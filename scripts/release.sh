#!/bin/bash
# One-command App Store release from a Mac that has Xcode signed in to your Apple ID.
#
#   scripts/release.sh                     # team MAP974T827, version 1.0.0, build number from the clock
#   scripts/release.sh TEAMID 1.0.1        # explicit marketing version
#   scripts/release.sh TEAMID 1.0.1 42     # explicit build number
#
# Find your Team ID at https://developer.apple.com/account under Membership details.
# Set BUNDLE_ID in the environment to override the default bundle identifier.
set -euo pipefail

TEAM_ID="${1:-MAP974T827}"
VERSION="${2:-1.0.0}"
BUILD="${3:-$(date +%Y%m%d%H%M)}"
BUNDLE_ID="${BUNDLE_ID:-com.messagegabrielhere.kept}"

cd "$(dirname "$0")/.."
mkdir -p build
ARCHIVE="build/Kept.xcarchive"

say() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

if ! command -v xcodebuild >/dev/null; then
  echo "Xcode is not installed. Install it from the Mac App Store, open it once, then re-run." >&2
  exit 1
fi
if ! command -v xcodegen >/dev/null; then
  if ! command -v brew >/dev/null; then
    echo "Homebrew is needed to install XcodeGen. Run this first, then re-run:" >&2
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
    exit 1
  fi
  say "Installing XcodeGen"
  brew install xcodegen
fi

say "Generating Kept.xcodeproj"
xcodegen generate --quiet

say "Archiving $BUNDLE_ID version $VERSION build $BUILD (team $TEAM_ID)"
rm -rf "$ARCHIVE"
set -o pipefail
xcodebuild archive \
  -project Kept.xcodeproj \
  -scheme Kept \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  CODE_SIGN_STYLE=Automatic \
  | tee build/archive.log \
  | (grep -E "error:|warning: .*(sign|provision)|\*\* ARCHIVE" || true)

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
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates \
  | tee build/export.log \
  | (grep -E "error:|Upload|EXPORT" || true)

say "Done. Build $BUILD of $VERSION is uploading. It appears under TestFlight in App Store Connect in 10 to 30 minutes."
