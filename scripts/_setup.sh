#!/bin/bash
# Shared checks for release.sh and screenshots.sh. Sourced, not run directly.
# Verifies Xcode is usable and makes an `xcodegen` command available with no Homebrew needed.

say() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

ensure_xcode() {
  if [ ! -d /Applications/Xcode.app ]; then
    fail "Xcode is not in /Applications. Install it from the Mac App Store, open it once, then re-run."
  fi
  case "$(xcode-select -p 2>/dev/null || true)" in
    */Xcode.app/*) ;;
    *)
      say "Pointing the command-line tools at Xcode (your Mac login password may be requested)"
      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
      ;;
  esac
  if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    say "Finishing Xcode's first-launch setup (your Mac login password may be requested)"
    sudo xcodebuild -runFirstLaunch
  fi
  if xcodebuild -version 2>&1 | grep -qi "license"; then
    say "Accepting the Xcode license (your Mac login password may be requested)"
    sudo xcodebuild -license accept
  fi
  say "Using $(xcodebuild -version | head -1)"
}

ensure_xcodegen() {
  if command -v xcodegen >/dev/null; then
    XCODEGEN=xcodegen
    return
  fi
  mkdir -p build
  if [ ! -x build/xcodegen/xcodegen/bin/xcodegen ]; then
    say "Downloading XcodeGen (one time, about 10 MB)"
    curl -fsSL -o build/xcodegen.zip \
      https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
    rm -rf build/xcodegen
    unzip -o -q build/xcodegen.zip -d build/xcodegen
  fi
  XCODEGEN=build/xcodegen/xcodegen/bin/xcodegen
}

generate_project() {
  ensure_xcodegen
  say "Generating Kept.xcodeproj"
  "$XCODEGEN" generate --quiet
}

show_errors_and_exit() {
  local log="$1"
  printf '\n\033[1;31mThe step above failed. Lines with errors:\033[0m\n' >&2
  grep -E "error:|error [0-9]|failed|Error Domain" "$log" | tail -20 >&2 || true
  printf '\nFull log: %s\nPaste the lines above to Claude.\n' "$log" >&2
  exit 1
}
