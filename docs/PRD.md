# Open Source Extradock macOS Client

**Version:** 1.0.0
**Status:** architecture_draft
**License:** MIT

## Description

A native, open-source macOS application providing a system-wide, floating dock alternative. Built with SwiftUI and AppKit interop for advanced window management features.

## Technology Stack

- **Language:** Swift
- **Framework:** SwiftUI (Primary), AppKit (Window Management)
- **Minimum Target:** macOS 14.0 (Sonoma)
- **Architecture:** MVVM with Dependencies

## Task Categories

| Category | Count | Description |
|----------|-------|-------------|
| Infrastructure | 5 | Project setup, Git, SPM, CI/CD |
| Core Logic | 6 | Data models, persistence, services |
| UI/Implementation | 16 | Views, window management, settings |
| System Integration | 5 | Launch at login, hotkeys, screen changes |
| Polish/UX | 5 | Animations, accessibility, localization |
| Release | 6 | App icon, DMG, Sparkle, notarization, docs |
| Advanced Features | 4 | Smart folders, URL handlers, window management |

**Total Tasks:** 48

---

## Must-Have Features (MVP)

### Core Dock Functionality
1. **Floating dock window** - Borderless, non-activating panel at configurable screen edge
2. **App launching** - Click icons to launch applications via NSWorkspace
3. **Drag & drop** - Add apps, files, URLs to dock by dragging
4. **Reorder items** - Drag to reorder dock items
5. **Running app indicators** - Visual dot/glow for running applications
6. **Persistence** - Save/load dock configuration to JSON
7. **Context menu** - Right-click options: Open, Remove, Rename, Reveal in Finder

### Settings
1. **General** - Launch at login, auto-hide, show on active space only
2. **Appearance** - Icon size (32-128px), opacity, spacing, show labels, monochrome icons
3. **Position** - Screen edge (left, right, bottom), offset slider

### System Integration
1. **Launch at login** - SMAppService for macOS 13+
2. **Global hotkey** - System-wide keyboard shortcut to toggle visibility
3. **Screen change handling** - Recalculate position on monitor disconnect/reconnect
4. **Status bar item** - Menu bar icon with Show/Hide, Settings, Quit

### Polish
1. **Auto-hide animation** - Smooth slide-out (0.2s ease-in-out)
2. **Window shadows** - Custom shadow for depth
3. **Accessibility** - VoiceOver labels and keyboard navigation
4. **Reduce motion** - Respect system accessibility preferences

### Release
1. **App icon** - All required sizes (16px to 1024px)
2. **Sparkle auto-updater** - Check for updates on launch
3. **Code signing & notarization** - Passes Gatekeeper
4. **README.md** - Features, installation, build instructions
5. **CONTRIBUTING.md** - Development setup, code style

---

## Nice-to-Have Features

1. **Folder popup** - Expand folder contents on click
2. **Smart folders** - Dynamic folder contents with FSWatch
3. **Mouse-over magnification** - Zoom effect on hover (configurable)
4. **Window management actions** - Quit, Hide, Show All Windows from context menu
5. **Import/Export configuration** - Share dock setup between machines
6. **Deep linking** - extradock:// URL scheme for adding items
7. **Localization** - en, es, fr, de

---

## Project Structure

```
Extradock/
├── Extradock.xcodeproj
├── Extradock/
│   ├── App/
│   │   ├── ExtradockApp.swift
│   │   └── AppDelegate.swift
│   ├── Models/
│   │   ├── DockItem.swift
│   │   └── DockGroup.swift
│   ├── ViewModels/
│   │   ├── DockViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/
│   │   ├── DockContainerView.swift
│   │   ├── DockIconCell.swift
│   │   ├── DockGridView.swift
│   │   ├── SettingsWindow/
│   │   └── Components/
│   ├── Services/
│   │   ├── PersistenceService.swift
│   │   ├── AppIconResolver.swift
│   │   ├── LaunchService.swift
│   │   ├── RunningAppsMonitor.swift
│   │   └── WindowObserver.swift
│   ├── Controllers/
│   │   └── MainWindowController.swift
│   └── Utilities/
│       └── Extensions/
├── ExtradockTests/
├── ExtradockUITests/
└── Packages/ (SPM dependencies)
```

---

## Dependencies (SPM)

| Package | Purpose | Required |
|---------|---------|----------|
| Sparkle | Auto-updates | Yes (for release) |
| Defaults | Preferences storage | Optional |
| KeyboardShortcuts | Global hotkey | Optional |

---

## CI/CD Requirements

- GitHub Actions workflow
- Build on push to main/develop
- Run tests
- Generate build artifacts
- Code signing and notarization (release builds)

---

## Acceptance Criteria

1. App builds with zero warnings on macOS 14.0+
2. Dock floats above all windows, including full-screen apps
3. Icons launch applications correctly
4. Drag & drop adds items to dock
5. Configuration persists between launches
6. Running app indicators update in real-time
7. Settings changes apply immediately
8. Auto-hide works smoothly on mouse exit
9. Launch at login works without helper app
10. Global hotkey toggles visibility system-wide
11. App passes Gatekeeper (notarized)
12. Sparkle auto-updater functions correctly
