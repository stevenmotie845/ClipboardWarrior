#!/bin/bash
# QA/run_portable_tests.sh
# Run from anywhere — does NOT touch the Xcode project.
# These harnesses are compiled as separate command-line tools so they never
# conflict with the app's own @main entry point.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.qa-build"
mkdir -p "$TMP/module-cache"

echo "==> Detector tests"
swiftc \
    -module-cache-path "$TMP/module-cache" \
    "$ROOT/ClipboardWarrior/Models.swift" \
    "$ROOT/ClipboardWarrior/Detector.swift" \
    "$ROOT/QA/DetectorHarness.swift" \
    "$ROOT/QA/DetectorMain.swift" \
    -o "$TMP/detector-tests"
"$TMP/detector-tests"

echo ""
echo "==> Retention tests"
swiftc \
    -module-cache-path "$TMP/module-cache" \
    "$ROOT/ClipboardWarrior/RetentionPolicy.swift" \
    "$ROOT/QA/RetentionHarness.swift" \
    "$ROOT/QA/RetentionMain.swift" \
    -o "$TMP/retention-tests"
"$TMP/retention-tests"

echo ""
echo "==> Swift syntax parse (all app sources)"
swiftc -frontend -parse "$ROOT"/ClipboardWarrior/*.swift

echo ""
echo "PASS: all portable tests and syntax checks completed."
