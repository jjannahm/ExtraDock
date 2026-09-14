import AppKit
import SwiftUI

// MARK: - AppDelegate

/// Menu bar app that runs both docks: the Mirror Dock (a copy of the system Dock
/// on other displays) and the Custom Dock (a dock you fill yourself).
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings(systemDockAutoHides: DockConfigReader.parse().autoHides)
    private let runningApps = RunningAppsMonitor()
    private let launchService = LaunchService()
    private var mirrorDock: MirrorDockController?
    private var customDock: CustomDockController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    override public init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory — no Dock icon for the app itself
        NSApp.setActivationPolicy(.accessory)

        let mirrorDock = MirrorDockController(settings: settings, runningApps: runningApps, launchService: launchService)
        let customDock = CustomDockController(
            settings: settings,
            viewModel: CustomDockViewModel(
                persistenceService: PersistenceService.shared,
                runningAppsMonitor: runningApps,
                launchService: launchService,
                iconResolver: AppIconResolver()
            )
        )
        // Keep the Custom Dock clear of a Mirror Dock on the same display edge.
        customDock.edgeInsetProvider = { [weak mirrorDock] screen, edge in
            mirrorDock?.occupiedDepth(on: screen, edge: edge) ?? 0
        }
        mirrorDock.onLayoutChange = { [weak customDock] in
            customDock?.layoutPanel()
        }
        self.mirrorDock = mirrorDock
        self.customDock = customDock

        setupStatusItem()
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged), name: .extraDockSettingsChanged, object: settings
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        screensChanged()
    }

    /// Opening the app again (e.g. from Finder or Spotlight) shows Settings, which
    /// helps when the menu bar icon is hidden behind the notch.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    @objc private func settingsChanged() {
        mirrorDock?.refresh()
        customDock?.refresh()
    }

    @objc private func screensChanged() {
        mirrorDock?.refresh(locateSystemDock: true)
        customDock?.refresh()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "ExtraDock")
        image?.isTemplate = true
        item.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let mirrorItem = ClosureMenuItem("Mirror Dock") { [weak self] in
            self?.settings.mirrorEnabled.toggle()
        }
        mirrorItem.state = settings.mirrorEnabled ? .on : .off
        menu.addItem(mirrorItem)
        if settings.mirrorEnabled, mirrorDock?.isMirroringAnyDisplay == false {
            let hint = NSMenuItem(title: "Not shown on any display — see Settings", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            hint.indentationLevel = 1
            menu.addItem(hint)
        }

        let customItem = ClosureMenuItem("Custom Dock") { [weak self] in
            self?.settings.customEnabled.toggle()
        }
        customItem.state = settings.customEnabled ? .on : .off
        menu.addItem(customItem)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Add to Custom Dock…") { [weak self] in
            self?.customDock?.addItemsWithOpenPanel()
        })
        let refreshItem = ClosureMenuItem("Refresh Mirror Dock") { [weak self] in
            self?.mirrorDock?.reloadDock()
        }
        refreshItem.isEnabled = settings.mirrorEnabled
        menu.addItem(refreshItem)
        if settings.mirrorEnabled && !BadgeReader.isAccessibilityGranted {
            menu.addItem(ClosureMenuItem("Allow Accessibility Access…") {
                BadgeReader.requestAccessibilityPermission()
            })
        }

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Settings…", keyEquivalent: ",") { [weak self] in
            self?.openSettings()
        })
        menu.addItem(NSMenuItem(title: "Quit ExtraDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // MARK: - Settings Window

    func openSettings() {
        if settingsWindow == nil, let customDock {
            let view = SettingsView(
                settings: settings,
                mirrorDockState: mirrorDock?.dockState ?? MirrorDockState(),
                customDockViewModel: customDock.viewModel,
                addCustomDockItems: { [weak customDock] in customDock?.addItemsWithOpenPanel() }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "ExtraDock Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
