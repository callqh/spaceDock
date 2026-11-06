#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SOURCE="$PROJECT_DIR/dist/SpaceDock.app"
APP_TARGET="$HOME/Applications/SpaceDock.app"
if [ ! -d "$APP_SOURCE" ]; then echo 'Run scripts/build.sh first.'; exit 1; fi
if pgrep -x SpaceDock >/dev/null; then echo 'Quit SpaceDock before installing an update.'; exit 1; fi
mkdir -p "$HOME/Applications"
if [ -e "$APP_TARGET" ]; then
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_TARGET/Contents/Info.plist")
    if [ "$BUNDLE_ID" != 'local.spacedock.app' ]; then echo 'Another application occupies the target path; nothing changed.'; exit 1; fi
    mkdir -p "$PROJECT_DIR/dist/install-backups"
    mv "$APP_TARGET" "$PROJECT_DIR/dist/install-backups/SpaceDock-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$APP_SOURCE" "$APP_TARGET"
# Remove the obsolete helper when rebuilding/upgrading an older local bundle.
rm -f "$APP_TARGET/Contents/Helpers/SpaceDockTouchProbe"
codesign --verify --deep --strict "$APP_TARGET"
touch "$APP_TARGET"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$APP_TARGET"
echo "Installed: $APP_TARGET"
open "$APP_TARGET" --args --settings
