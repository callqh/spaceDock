#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun clang -fobjc-arc -framework Foundation -framework ApplicationServices     Tests/WindowSelectionTests/main.m -o "$TEST_DIR/window-selection-tests"
"$TEST_DIR/window-selection-tests"
