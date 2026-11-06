<p align="center">
  <img src="design/icon-concepts/spacebar-portal-v1.png" width="112" alt="SpaceDock spacebar portal icon">
</p>

# SpaceDock

**English** | [简体中文](README.zh-CN.md)

A lightweight, native macOS app launcher. Hold Space, press a key, and bring your favorite apps into view.

- **Space + your key**: Open an app. Press the shortcut again to hide it when its window is in the foreground.
- **Summon to the current desktop**: Bring an app's main window to your current regular desktop. It stays there when you switch away.
- **Make it yours**: Add and edit shortcuts, adjust the hold delay, exclude apps, or pause shortcuts.
- **Stay out of the way**: Launch at login or hide the menu bar icon. Closing settings keeps SpaceDock running in the background.
- **Keep it local**: No account required. Settings stay on your Mac, and typed content is not recorded.

## Installation

Download the latest ZIP for your version and architecture from [Releases](https://github.com/callqh/spaceDock/releases),
extract it, and move SpaceDock.app to ~/Applications or your Applications folder.

Current releases target **Apple Silicon (M-series Macs)** with a minimum deployment target of macOS 13.
The minimum macOS version has not been tested on a physical device. Intel Macs, full-screen Spaces, and compatibility across all macOS versions are not guaranteed.

The app is ad-hoc signed, without Developer ID signing or Apple notarization.
macOS may ask you to confirm opening it in **System Settings → Privacy & Security**.
Only do this for a package whose source you trust; you do not need to disable system security protections.

On first launch, enable SpaceDock in **System Settings → Privacy & Security → Accessibility**.
After a local build or update, if the app reports that permission is required, remove the old entry,
add the currently installed SpaceDock.app, and enable it again. Complete any authentication prompts yourself.

## Usage

The settings interface is currently in Chinese; the labels below include their English meanings.

1. Open settings, click **添加应用** (Add App), select an app, and assign a letter or number.
2. Hold Space until the configured delay has elapsed, then press the assigned key, such as **Space + W**.
3. Enable **当前桌面** (Current Desktop) for apps you want to bring to your current desktop.

| Mode | Behavior |
| --- | --- |
| Current Desktop on | Moves the main window before activating it. The window stays behind when you switch desktops. |
| Current Desktop off | Activates the app normally. Switching to its existing window's desktop depends on your macOS settings. |

For ordinary activation to switch to the desktop containing an app's window, enable
**Desktop & Dock → Mission Control → When switching to an application, switch to a Space with open windows for the application** in System Settings.

When you enable Current Desktop, SpaceDock attempts to set the app's Dock menu **Options → Assign To** setting to **None**.
Only the main window is moved; separate chat windows may not follow, and full-screen windows are not supported.
This feature uses private macOS window APIs and may need updates after macOS upgrades.

A quick tap of Space still types a space. The default hold delay is 200 ms and can be adjusted in preferences.
Close settings with the red close button or **⌘W**. If you hide the menu bar icon, reopen SpaceDock through Spotlight or Finder to return to settings.

See the [user guide (Chinese)](docs/USER_GUIDE.md) for more details.

## Local Development

Requires macOS, a Swift 6 toolchain (tests use Swift Testing), and Xcode or Command Line Tools.

    git clone https://github.com/callqh/spaceDock.git
    cd spaceDock
    bash scripts/test.sh
    bash scripts/build.sh
    # Quit any running instance of SpaceDock before installing.
    bash scripts/install.sh

- SwiftPM project using SwiftUI and AppKit, with no third-party runtime dependencies.
- The version comes from VERSION. Override it for a local build with the SPACEDOCK_VERSION environment variable.
- Outputs: dist/SpaceDock.app, a ZIP named with the version and architecture, and a SHA-256 checksum file.
- The installer moves the previous app to dist/install-backups/, then installs a fresh copy at ~/Applications/SpaceDock.app. User settings are preserved.
- The local CLT 27 setup has a SwiftUI macro plugin issue. Scripts prefer the installed macOS 26.5 SDK, falling back to the active toolchain SDK. Set SPACEDOCK_SDK to choose an SDK explicitly.
- Passing tests and builds does not replace real-device testing of global shortcuts, permissions, or desktop switching.

Example version override:

    SPACEDOCK_VERSION=1.1.0 bash scripts/build.sh

## Automated Builds and Releases

The workflow lives in [release.yml](.github/workflows/release.yml):

- **Pull requests or manual runs**: Run tests and upload build artifacts without publishing a release.
- **Push a vX.Y.Z tag**: Verify that the tag matches VERSION, then test, build, and publish a GitHub Release with the ZIP, SHA-256 checksum, and generated release notes.
- Uses the [GitHub-hosted macos-15 Apple Silicon runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). Only the release job receives write permissions; no extra repository secrets are needed.
- CI packages are also ad-hoc signed. Developer ID signing and notarization are not configured.

To publish a new version, first update VERSION, commit, and merge the changes.
For example, after setting VERSION to 1.1.1:

    git tag v1.1.1
    git push origin v1.1.1

Tags should point to reviewed commits. Check the Actions logs if a run fails.
Do not move a published version tag; increment the version for subsequent fixes.

## Project Documentation

The following documents are currently in Chinese:

- [Requirements](spec.md) · [Intent](INTENT.md) · [Decision records](DECISION.md)
- [Architecture](docs/architecture.md) · [Verification records](docs/verification.md)
- [Design tokens](docs/design-tokens.md) · [Design prototype](design/index.html)

The HTML prototype is a visual reference. The native app implementation lives in Sources.
