import AppKit
import UniformTypeIdentifiers

// MARK: - CustomDockController

/// Owns the Custom Dock window: shows or hides it per settings, keeps it sized
/// and attached to the chosen edge, and handles drops and item menus.
@MainActor
final class CustomDockController {
    let viewModel: CustomDockViewModel
    private let settings: AppSettings
    private var panel: DockPanel?

    /// Extra distance to keep from `edge` of a screen, so the Custom Dock sits
    /// beside (not under) a Mirror Dock on the same edge.
    var edgeInsetProvider: ((NSScreen, DockEdge) -> CGFloat)?

    init(settings: AppSettings, viewModel: CustomDockViewModel) {
        self.settings = settings
        self.viewModel = viewModel
        viewModel.onItemsChanged = { [weak self] in
            self?.layoutPanel()
        }
    }

    // MARK: Lifecycle

    /// Applies current settings: creates or removes the panel, then lays it out.
    func refresh() {
        guard settings.isCustomDockActive(externalDisplayConnected: DisplayIdentity.isExternalDisplayConnected) else {
            panel?.close()
            panel = nil
            return
        }
        if panel == nil {
            panel = makePanel()
        }
        layoutPanel()
    }

    private func makePanel() -> DockPanel {
        let panel = DockPanel(showsOverFullScreenApps: true)
        let dropView = CustomDockDropView(frame: .zero)
        dropView.layoutProvider = { [weak self] in
            self?.viewModel.layout ?? .placeholder
        }
        dropView.onHover = { [weak self] index in
            guard let self, self.viewModel.dropIndex != index else { return }
            self.viewModel.dropIndex = index
        }
        dropView.onDrop = { [weak self] drop in
            self?.perform(drop) ?? false
        }
        let rootView = CustomDockView(
            viewModel: viewModel,
            settings: settings,
            menu: { [weak self] item in
                self?.menu(for: item) ?? NSMenu()
            },
            beginResize: { [weak self] in
                CGFloat(self?.settings.customIconSize ?? 64)
            },
            resize: { [weak self] startSize, distance in
                self?.settings.customIconSize = AppSettings.customIconSize(resizingFrom: Double(startSize), by: distance)
            }
        )
        panel.setRootView(rootView, container: dropView)
        return panel
    }

    // MARK: Layout

    private var targetScreen: NSScreen? {
        DisplayIdentity.screen(forKey: settings.customDisplay) ?? DisplayIdentity.primaryScreen
    }

    func layoutPanel() {
        guard let panel, let screen = targetScreen else { return }
        let edge = settings.customEdge
        let visibleFrame = screen.visibleFrame
        let layout = CustomDockLayout(
            edge: edge,
            itemCount: viewModel.items.count,
            iconSize: settings.customIconSize,
            spacing: settings.customIconSpacing,
            showLabels: settings.customShowLabels,
            magnification: settings.customMagnification ? settings.customMagnificationScale : 1,
            availableLength: DockGeometry.availableLength(along: edge, in: visibleFrame)
        )
        viewModel.layout = layout

        let origin = DockGeometry.origin(
            edge: edge,
            size: layout.panelSize,
            in: visibleFrame,
            offset: settings.customOffset,
            inset: edgeInsetProvider?(screen, edge) ?? 0
        )
        panel.update(
            frame: NSRect(origin: origin, size: layout.panelSize),
            edge: edge,
            screenFrame: screen.frame,
            visibility: visibility
        )
    }

    /// An empty Custom Dock stays out of sight and only slides in as a drop target
    /// when something is dragged to its edge.
    private var visibility: DockVisibility {
        if viewModel.items.isEmpty { return .revealWhileDragging }
        return settings.customAutoHide ? .autoHide : .pinned
    }

    // MARK: Adding items

    func addItemsWithOpenPanel() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Add to Custom Dock"
        openPanel.prompt = "Add"
        openPanel.message = "Choose apps, files, or folders to add to the Custom Dock."
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = true
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate()
        guard openPanel.runModal() == .OK else { return }
        if !settings.customEnabled {
            settings.customEnabled = true
        }
        if viewModel.addItems(from: openPanel.urls) > 0 {
            // A hidden dock would give no sign anything happened; show where the items went.
            panel?.peek()
        }
    }

    private func perform(_ drop: CustomDockDropView.Drop) -> Bool {
        switch drop {
        case let .move(itemID, insertionIndex):
            viewModel.moveItem(id: itemID, toInsertionIndex: insertionIndex)
            return true
        case let .add(urls, insertionIndex):
            return viewModel.addItems(from: urls, at: insertionIndex) > 0
        }
    }

    // MARK: Item menu

    private func menu(for item: CustomDockItem) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem("Open") { [weak self] in
            self?.viewModel.launchItem(item)
        })
        if item.type != .url {
            menu.addItem(ClosureMenuItem("Show in Finder") { [weak self] in
                self?.viewModel.revealInFinder(item)
            })
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Rename…") { [weak self] in
            // Let the menu finish closing before running a modal alert.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.promptRename(item) }
            }
        })
        menu.addItem(ClosureMenuItem("Remove from Dock") { [weak self] in
            self?.viewModel.removeItem(item)
        })
        return menu
    }

    /// The dock panel can't take keyboard focus, so rename in a regular alert.
    private func promptRename(_ item: CustomDockItem) {
        let alert = NSAlert()
        alert.messageText = "Rename “\(item.displayName)”"
        alert.informativeText = "This only changes the name shown in the Custom Dock."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: item.displayName)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        viewModel.renameItem(item, to: field.stringValue)
    }
}
