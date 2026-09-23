#!/bin/bash
# Builds Kept and installs it straight onto a connected iPhone. No TestFlight, no App Store
# Connect, no waiting for an invite email.
#
#   scripts/install_on_phone.sh
#
# Requirements: the phone plugged in with a data cable, unlocked, and trusted (tap "Trust" on
# the phone the first time). Xcode must be signed in to your Apple ID under Settings > Accounts.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_setup.sh

TEAM_ID="${TEAM_ID:-MAP974T827}"
BUNDLE_ID="${BUNDLE_ID:-com.messagegabrielhere.kept}"

ensure_xcode

say "Looking for a connected iPhone"
DEVICES_JSON="build/devices.json"
mkdir -p build
xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1 || true

UDID=""
NAME=""
if [ -f "$DEVICES_JSON" ]; then
  read -r UDID NAME <<<"$(python3 - "$DEVICES_JSON" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
for d in devices:
    props = d.get("deviceProperties", {})
    hardware = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    if hardware.get("platform") != "iOS":
        continue
    if conn.get("tunnelState") == "unavailable" and conn.get("pairingState") != "paired":
        continue
    print(d.get("identifier", ""), props.get("name", "iPhone"))
    break
PY
)"
fi

if [ -z "$UDID" ]; then
  cat >&2 <<'MSG'

ERROR: no iPhone found.

Work through these in order, then run this script again:
  1. Use a cable that carries data. Many charging cables and most car cables do not.
     If the phone charges but nothing else happens, that is the usual culprit.
  2. Unlock the phone and leave it on the home screen.
  3. Watch the phone for a "Trust This Computer?" prompt. Tap Trust, then enter the passcode.
     If you missed it: unplug, lock the phone, unlock it, plug back in.
  4. If no prompt ever appears, reset the pairing on the phone:
     Settings > General > Transfer or Reset iPhone > Reset > Reset Location & Privacy.
     Then plug in again and tap Trust.
  5. Open Xcode once, then Window > Devices and Simulators, and check the phone is listed.

MSG
  exit 1
fi

say "Found $NAME"

generate_project

say "Building and signing for the device (this registers the phone with your account)"
set +e
xcodebuild build \
  -project Kept.xcodeproj \
  -scheme Kept \
  -configuration Debug \
  -destination "platform=iOS,id=$UDID" \
  -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  > build/device-build.log 2>&1
status=$?
set -e
[ $status -eq 0 ] || show_errors_and_exit build/device-build.log

APP="build/DerivedData/Build/Products/Debug-iphoneos/Kept.app"
[ -d "$APP" ] || fail "Build succeeded but $APP is missing. See build/device-build.log."

say "Installing onto $NAME"
xcrun devicectl device install app --device "$UDID" "$APP"

cat <<MSG

Installed. Kept is on the home screen of $NAME.

The first launch will refuse to open with a message about an untrusted developer. That is
normal for a build installed this way. On the phone:

    Settings > General > VPN & Device Management > your Apple ID > Trust

Then open Kept and it will work normally. Recording steps: docs/SCREEN_RECORDING.md

MSG
