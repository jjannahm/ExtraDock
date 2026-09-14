# ExtraDock

A macOS menu bar app with two extra docks:

- **Mirror Dock** — macOS only shows the Dock on one display at a time. The Mirror Dock renders a faithful, interactive copy of it on your other displays.
- **Custom Dock** — a separate floating dock that holds whatever you put in it: apps, files, folders, and web links.

This repository merges two open-source projects, with both histories preserved:
[henningziech/extradock](https://github.com/henningziech/extradock) (Mirror Dock) and
[johnnyclem/anotherdock](https://github.com/johnnyclem/anotherdock) (Custom Dock).

## Features

### Mirror Dock
- Mirrors pinned apps, recent apps, and persistent folders from your real Dock
- Follows the Dock's position (bottom, left, or right) and hides recent apps when the Dock does
- Shows on every display except the one the system Dock is on; change this per display in Settings
- Running-app indicator dots and unread badges
- Click to launch or switch to apps; folders open in Finder
- Right-click shows the Dock's own app menu (needs Accessibility access)
- Live sync: updates within seconds when you change your Dock
- Scale slider and optional hide-after-inactivity

### Custom Dock
- Drag apps, files, folders, or links onto it; drag icons to reorder
- Right-click to open, show in Finder, rename, or remove
- Place it on the bottom, left, or right edge of any display, with an offset
- Icon size, spacing, labels, monochrome icons, opacity, hover magnification
- Optional auto-hide when the pointer leaves
- Running-app indicators; saved in `~/Library/Application Support/ExtraDock/`

### Both
- One menu bar icon to toggle each dock, add items, and open Settings
- Frosted glass look, launch at login, no Dock icon of its own
- If the menu bar icon is hidden (e.g. behind the notch), open ExtraDock again from Finder or Spotlight to get Settings

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16+ or its Command Line Tools (for building from source)

## Installation

```bash
git clone <this repository>
cd ExtraDock
./install.sh
```

`install.sh` builds a release version with Swift Package Manager, wraps it in `ExtraDock.app`, installs it to `/Applications` (or `~/Applications` if that isn't writable), and launches it. Use `./install.sh --build-only` to just produce `build/ExtraDock.app`.

### Develop

```bash
swift build   # debug build
swift test    # run the test suite
open Package.swift   # work in Xcode
```

## Usage

1. Launch ExtraDock — a dock icon appears in the menu bar.
2. The Mirror Dock appears on displays that don't have the system Dock. The Custom Dock appears at the bottom of your main display, ready for you to drop apps on it.
3. Click the menu bar icon to turn either dock on or off, add items to the Custom Dock, refresh the Mirror Dock, or open **Settings** (General, Mirror Dock, Custom Dock).

### Accessibility access (optional)

The Mirror Dock reads badges and the Dock's right-click menus through the Accessibility API. macOS asks for permission the first time a Mirror Dock appears; you can also grant it later from Settings › General. Everything else works without it.

Because `install.sh` signs the app ad hoc, macOS treats each rebuild as a new app. After reinstalling, turn ExtraDock off and on again in System Settings › Privacy & Security › Accessibility.

## How It Works

The Mirror Dock reads your Dock configuration from `~/Library/Preferences/com.apple.dock.plist`, watches it for changes, and finds which display the Dock is on from its window position. Both docks use `NSWorkspace` to track running apps and render in floating, non-activating `NSPanel` windows.

## Not Sandboxed

ExtraDock needs direct access to the Dock preferences and to other apps through the Accessibility API, so it cannot be sandboxed and is not eligible for the Mac App Store.

## License

MIT, as declared by both upstream projects.
