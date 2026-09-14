// MirrorDockController.swift
import AppKit

/// Mirrors the system Dock onto the displays chosen in Settings: keeps one
/// `MirrorDockPanel` per display and keeps Dock contents, running state and
/// badges up to date while mirroring is on.
@MainActor
final class MirrorDockController {
    let dockState = MirrorDockState()
    private let settings: AppSettings
    private let runningApps: RunningAppsMonitor
    private let launchService: LaunchService
    private let plistWatcher = DockPlistWatcher()
    private let badgeReader = BadgeReader()
    private var panels: [String: MirrorDockPanel] = [:]
    private var servicesRunning = false
    /// Display the system Dock was on at the last refresh.
    private(set) var systemDockDisplayKey: String?
    private var dockLocationTimer: Timer?

    /// Called after panels are added, removed, or resized.
    var onLayoutChange: (() -> Void)?

    init(settings: AppSettings, runningApps: RunningAppsMonitor, launchService: LaunchService) {
        self.settings = settings
        self.runningApps = runningApps
        self.launchService = launchService

        plistWatcher.onChange = { [weak self] in
            self?.reloadDock()
        }
        runningApps.onChange = { [weak self] bundleIDs in
            self?.dockState.updateRunningApps(bundleIDs)
        }
        badgeReader.onChange = { [weak self] badges in
            self?.dockState.updateBadges(badges)
        }
    }

    var isMirroringAnyDisplay: Bool {
        !panels.isEmpty
    }

    // MARK: Refresh

    /// Applies settings and the current display arrangement. Pass `locateSystemDock`
    /// when displays or the Dock may have moved; settings changes (such as dragging
    /// to resize, many times a second) skip that lookup.
    func refresh(locateSystemDock: Bool = false) {
        let wasRunning = servicesRunning
        let isActive = settings.isMirrorDockActive(
            externalDisplayConnected: DisplayIdentity.isExternalDisplayConnected
        )
        if isActive {
            startServices()
        } else {
            stopServices()
        }
        if locateSystemDock || !wasRunning {
            systemDockDisplayKey = SystemDockLocator.displayKey(orientation: dockState.edge)
        }
        let screens = isActive ? NSScreen.screens.filter(shouldMirror(on:)) : []

        var wantedKeys = Set<String>()
        for screen in screens {
            guard let key = DisplayIdentity.key(for: screen) else { continue }
            wantedKeys.insert(key)
            let panel = panels[key] ?? MirrorDockPanel(dockState: dockState, launchService: launchService, settings: settings)
            panels[key] = panel
            panel.layout(on: screen, scale: settings.mirrorScale, autoHide: settings.mirrorAutoHide)
        }
        for (key, panel) in panels where !wantedKeys.contains(key) {
            panel.close()
            panels.removeValue(forKey: key)
        }

        if !panels.isEmpty {
            // Badges and native menus need Accessibility; ask once a mirror is actually on screen.
            badgeReader.start(requestAccess: true)
        }
        onLayoutChange?()
    }

    /// Re-reads the Dock preferences (e.g. from the menu bar's "Refresh Mirror Dock").
    func reloadDock() {
        dockState.apply(DockConfigReader.parse())
        dockState.updateRunningApps(runningApps.runningBundleIDs)
        dockState.updateBadges(badgeReader.badges)
        refresh(locateSystemDock: true)
    }

    func shouldMirror(on screen: NSScreen) -> Bool {
        guard let key = DisplayIdentity.key(for: screen) else { return false }
        return settings.isMirrorEnabled(onDisplay: key, hasSystemDock: key == systemDockDisplayKey)
    }

    /// Depth a Mirror Dock occupies on `edge` of `screen` (plus a small gap), or 0.
    func occupiedDepth(on screen: NSScreen, edge: DockEdge) -> CGFloat {
        guard let key = DisplayIdentity.key(for: screen), let panel = panels[key], panel.edge == edge else {
            return 0
        }
        return (edge.isVertical ? panel.frame.width : panel.frame.height) + 4
    }

    // MARK: Services

    private func startServices() {
        guard !servicesRunning else { return }
        servicesRunning = true
        dockState.apply(DockConfigReader.parse())
        dockState.updateRunningApps(runningApps.runningBundleIDs)
        plistWatcher.start()
        // A bottom Dock follows the pointer between displays; move the mirrors with it.
        dockLocationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkSystemDockLocation() }
        }
    }

    private func stopServices() {
        guard servicesRunning else { return }
        servicesRunning = false
        plistWatcher.stop()
        badgeReader.stop()
        dockLocationTimer?.invalidate()
        dockLocationTimer = nil
    }

    private func checkSystemDockLocation() {
        guard NSScreen.screens.count > 1,
              SystemDockLocator.displayKey(orientation: dockState.edge) != systemDockDisplayKey else { return }
        refresh(locateSystemDock: true)
    }
}
