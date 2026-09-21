#!/bin/bash
# Captures App Store screenshots from the iOS Simulator with demo data loaded.
#
#   scripts/screenshots.sh
#
# Produces build/screenshots/<device>-list.png for the 6.9-inch iPhone and 13-inch iPad.
# For the detail and editor screenshots, the simulator stays open: tap a habit and press
# Cmd-S in the Simulator app to save more images to your Desktop.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_setup.sh
mkdir -p build/screenshots

ensure_xcode
generate_project

pick_device() {
  # Prints the UDID of the first available simulator whose name matches any pattern given.
  for pattern in "$@"; do
    udid=$(xcrun simctl list devices available | grep -E "^\s*$pattern \(" | head -1 | grep -oE "[0-9A-F-]{36}" || true)
    if [ -n "$udid" ]; then echo "$udid"; return; fi
  done
  return 1
}

IPHONE=$(pick_device "iPhone 17 Pro Max" "iPhone 16 Pro Max" "iPhone 15 Pro Max") || { echo "No Pro Max iPhone simulator found. In Xcode: Settings > Components, install the latest iOS simulator." >&2; exit 1; }
IPAD=$(pick_device "iPad Pro 13-inch \(M5\)" "iPad Pro 13-inch \(M4\)" "iPad Pro \(12.9-inch\) \(6th generation\)") || { echo "No 13-inch iPad simulator found." >&2; exit 1; }

echo "Building for the simulator"
xcodebuild build \
  -project Kept.xcodeproj \
  -scheme Kept \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  | (grep -E "error:|\*\* BUILD" || true)

APP="build/DerivedData/Build/Products/Debug-iphonesimulator/Kept.app"
BUNDLE_ID=$(defaults read "$PWD/$APP/Info" CFBundleIdentifier)

capture() {
  local udid="$1" label="$2"
  echo "Capturing $label"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  xcrun simctl install "$udid" "$APP"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$udid" "$BUNDLE_ID" -demo >/dev/null
  sleep 3
  xcrun simctl io "$udid" screenshot "build/screenshots/$label-list.png"
}

capture "$IPHONE" iphone
capture "$IPAD" ipad
open -a Simulator

echo
echo "Saved build/screenshots/iphone-list.png and build/screenshots/ipad-list.png."
echo "In the Simulator, tap a habit and press Cmd-S for the detail screenshot, then + for the editor."
