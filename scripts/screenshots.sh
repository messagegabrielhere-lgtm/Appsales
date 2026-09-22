#!/bin/bash
# Produces the App Store screenshot sets Apple requires, ready to drag into App Store Connect:
#
#   build/screenshots/iphone-6.5-inch/   widgets list detail editor .jpg   (1284 x 2778)
#   build/screenshots/ipad-13-inch/      widgets list detail editor .jpg   (2048 x 2732)
#   build/screenshots/marketing/...      the same with captions, if Pillow is installed
#
#   scripts/screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_setup.sh

ensure_xcode
generate_project

pick_device() {
  # Prints the UDID of the first available simulator whose name matches any pattern given.
  local pattern udid
  for pattern in "$@"; do
    udid=$(xcrun simctl list devices available | grep -E "^\s*$pattern" | head -1 | grep -oE "[0-9A-F-]{36}" || true)
    if [ -n "$udid" ]; then echo "$udid"; return 0; fi
  done
  return 1
}

IPHONE=$(pick_device "iPhone [0-9]+ Pro Max" "iPhone [0-9]+ Plus" "iPhone [0-9]+ Pro" "iPhone") \
  || fail "No iPhone simulator found. In Xcode: Settings > Components, install an iOS simulator."
IPAD=$(pick_device "iPad Pro 13-inch" "iPad Pro \(12.9-inch\)" "iPad Air 13-inch" "iPad") \
  || fail "No iPad simulator found. In Xcode: Settings > Components, install an iOS simulator."

say "Building for the simulator"
set +e
xcodebuild build \
  -project Kept.xcodeproj \
  -scheme Kept \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  > build/simulator-build.log 2>&1
status=$?
set -e
[ $status -eq 0 ] || show_errors_and_exit build/simulator-build.log

APP="build/DerivedData/Build/Products/Debug-iphonesimulator/Kept.app"
BUNDLE_ID=$(defaults read "$PWD/$APP/Info" CFBundleIdentifier)

capture_set() {
  local udid="$1" label="$2" width="$3" height="$4" screen out
  say "Capturing $label"
  mkdir -p "build/screenshots/$label"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  xcrun simctl install "$udid" "$APP"
  for screen in widgets list detail editor; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -demo -screen "$screen" >/dev/null
    sleep 4
    out="build/screenshots/$label/$screen"
    xcrun simctl io "$udid" screenshot "$out.png" >/dev/null
    # App Store Connect wants exact pixel sizes and no transparency.
    sips -z "$height" "$width" "$out.png" >/dev/null
    sips -s format jpeg -s formatOptions 92 "$out.png" --out "$out.jpg" >/dev/null
    rm -f "$out.png"
    echo "  $out.jpg"
  done
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
}

capture_set "$IPHONE" "iphone-6.5-inch" 1284 2778
capture_set "$IPAD" "ipad-13-inch" 2048 2732

if python3 -c "import PIL" 2>/dev/null; then
  say "Adding captions"
  python3 scripts/marketing/compose.py
  FINAL="build/screenshots/marketing"
else
  echo "Pillow is not installed, so no captions were added. Optional: pip3 install pillow, then run python3 scripts/marketing/compose.py"
  FINAL="build/screenshots"
fi
[ -n "${CI:-}" ] || open "$FINAL"
say "Done. Upload $FINAL/iphone-6.5-inch/*.jpg to the iPhone 6.5\" tab and $FINAL/ipad-13-inch/*.jpg to the iPad 13\" tab, in file order."
