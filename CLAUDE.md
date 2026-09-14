# ExtraDock

macOS menu bar app combining two upstream projects:

- **Mirror Dock** — from [henningziech/extradock](https://github.com/henningziech/extradock): an interactive copy of the system Dock on other displays (`Sources/ExtraDockKit/MirrorDock`).
- **Custom Dock** — from [johnnyclem/anotherdock](https://github.com/johnnyclem/anotherdock): a floating dock the user fills by drag and drop (`Sources/ExtraDockKit/CustomDock`).

Both upstream histories are merged into this repo (see `git log --graph`).

## Layout

- `Sources/ExtraDockKit` — all logic and UI (library, unit tested)
  - `App/` AppDelegate: menu bar item, settings window, wires both docks together
  - `Shared/` DockPanel (floating panel + auto-hide), DockGeometry, item mouse handling, launch/running-app services
  - `Settings/` AppSettings (UserDefaults-backed `@Observable`) and the settings tabs
- `Sources/ExtraDock` — executable entry point only
- `Tests/ExtraDockKitTests` — XCTest suite
- `Resources/Info.plist` — bundle metadata copied into the app by `install.sh`

## Build & Test

Swift Package Manager only (no Xcode project):

```bash
swift build
swift test
./install.sh               # build release app, install to /Applications, launch
./install.sh --build-only  # just produce build/ExtraDock.app
```

## Git Workflow

- Branch: main
- Commit after completing a logical unit of work
- Do not push to either upstream repository
