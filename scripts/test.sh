#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK_PATH="${SPACEDOCK_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
if [ ! -d "$SDK_PATH" ]; then SDK_PATH="$(xcrun --show-sdk-path)"; fi
if [[ "$(xcode-select -p)" != "/Library/Developer/CommandLineTools" ]]; then
    exec swift test --sdk "$SDK_PATH"
fi
swift test --build-system native --sdk "$SDK_PATH" --disable-xctest \
    -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
    -Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib \
    -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
