#!/bin/bash
# Runs the model and logic unit tests with plain Swift, no Xcode or simulator: on Linux in CI
# (about a minute) or on a Mac. The full suite still runs in Xcode via the CI workflow.
#
#   scripts/test_logic.sh
set -euo pipefail
cd "$(dirname "$0")/.."

work=build/logic-package
rm -rf "$work"
mkdir -p "$work/Sources/Kept" "$work/Tests/KeptTests"

cp Kept/Models/*.swift Kept/Logic/*.swift Kept/Shared/Brand.swift "$work/Sources/Kept/"
for test in TestSupport DayKeyTests LogEntryTests LogInsightsTests AIExportTests StreakCalculatorTests \
            ReminderPlannerTests HabitCodableTests BulkEntryParserTests CSVImportTests BackupMergeTests ReviewPromptTests; do
  cp "KeptTests/$test.swift" "$work/Tests/KeptTests/"
done

cat > "$work/Package.swift" <<'SWIFT'
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kept",
    targets: [
        .target(name: "Kept"),
        .testTarget(name: "KeptTests", dependencies: ["Kept"]),
    ]
)
SWIFT

cd "$work"
swift test 2>&1 | grep -vE "^\[[0-9]+/[0-9]+\] (Compiling|Emitting|Write|Building)" || exit "${PIPESTATUS[0]}"
