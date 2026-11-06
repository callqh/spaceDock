#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
# The installed 27.0 CLT SDK lacks SwiftUIMacros. 26.5 supports macOS 13+ wrappers.
SDK_PATH="${SPACEDOCK_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
if [ ! -d "$SDK_PATH" ]; then SDK_PATH="$(xcrun --show-sdk-path)"; fi
swift build --build-system native --sdk "$SDK_PATH" -c release
BIN_DIR="$(swift build --build-system native --sdk "$SDK_PATH" -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/SpaceDock.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/dist/AppIcon.iconset"
# Remove the obsolete helper when rebuilding/upgrading an older local bundle.
rm -f "$APP_DIR/Contents/Helpers/SpaceDockTouchProbe"
cp "$BIN_DIR/SpaceDock" "$APP_DIR/Contents/MacOS/SpaceDock"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SpaceDock</string>
<key>CFBundleIdentifier</key><string>local.spacedock.app</string>
<key>CFBundleName</key><string>SpaceDock</string>
<key>CFBundleDisplayName</key><string>SpaceDock</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict></plist>
PLIST
swift -sdk "$SDK_PATH" scripts/make-icon.swift "$PROJECT_DIR/dist/icon-1024.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$PROJECT_DIR/dist/icon-1024.png" --out "$PROJECT_DIR/dist/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$PROJECT_DIR/dist/icon-1024.png" --out "$PROJECT_DIR/dist/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$PROJECT_DIR/dist/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier local.spacedock.app "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$PROJECT_DIR/dist/SpaceDock-1.0.0-macOS.zip"
echo "Built: $APP_DIR"
