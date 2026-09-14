import AppKit
import Foundation
import Observation

// MARK: - CustomDockViewModel

/// State and actions for the user-curated Custom Dock.
@MainActor
@Observable
final class CustomDockViewModel {
    private(set) var items: [CustomDockItem] = []
    private(set) var groups: [CustomDockGroup] = []
    /// Current geometry, set by the controller for the screen the dock is on.
    var layout: CustomDockLayout = .placeholder
    /// Insertion index highlighted while something is dragged over the dock.
    var dropIndex: Int?

    /// Called after any change to `items`, so the window can resize.
    @ObservationIgnored var onItemsChanged: (() -> Void)?

    @ObservationIgnored private let persistenceService: any PersistenceServiceProtocol
    @ObservationIgnored let runningAppsMonitor: RunningAppsMonitor
    @ObservationIgnored let launchService: LaunchService
    @ObservationIgnored let iconResolver: AppIconResolver

    // Designated init — used in tests for dependency injection
    init(
        persistenceService: any PersistenceServiceProtocol,
        runningAppsMonitor: RunningAppsMonitor,
        launchService: LaunchService,
        iconResolver: AppIconResolver
    ) {
        self.persistenceService = persistenceService
        self.runningAppsMonitor = runningAppsMonitor
        self.launchService = launchService
        self.iconResolver = iconResolver
        loadConfiguration()
    }

    // MARK: - Configuration

    func loadConfiguration() {
        do {
            let config = try persistenceService.load()
            items = config.items.sorted { $0.sortOrder < $1.sortOrder }
            groups = config.groups
        } catch {
            NSLog("ExtraDock: failed to load Custom Dock configuration: \(error.localizedDescription)")
            items = []
            groups = []
        }
        onItemsChanged?()
    }

    func saveConfiguration() {
        let config = CustomDockConfiguration(items: items, groups: groups)
        do {
            try persistenceService.save(config)
        } catch {
            NSLog("ExtraDock: failed to save Custom Dock configuration: \(error.localizedDescription)")
        }
    }

    // MARK: - Item Management

    func addItem(_ item: CustomDockItem) {
        insert([item], at: items.count)
    }

    func addItemFromURL(_ url: URL) {
        addItems(from: [url])
    }

    /// Adds apps, files, folders, or web links. Paths already in the dock are
    /// skipped. Returns how many items were added.
    @discardableResult
    func addItems(from urls: [URL], at index: Int? = nil) -> Int {
        var seenPaths = Set(items.map(\.path))
        let newItems = urls.compactMap { url -> CustomDockItem? in
            guard let item = Self.makeItem(from: url), seenPaths.insert(item.path).inserted else { return nil }
            return item
        }
        guard !newItems.isEmpty else { return 0 }
        insert(newItems, at: index ?? items.count)
        return newItems.count
    }

    func removeItem(_ item: CustomDockItem) {
        items.removeAll { $0.id == item.id }
        commitItemChange()
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        commitItemChange()
    }

    /// Moves the item with `id` so it lands at `insertionIndex` (0...items.count,
    /// measured before the move, as reported by `CustomDockLayout`).
    func moveItem(id: UUID, toInsertionIndex insertionIndex: Int) {
        guard let from = items.firstIndex(where: { $0.id == id }) else { return }
        let destination = min(max(insertionIndex, 0), items.count)
        guard destination != from, destination != from + 1 else { return }
        moveItem(from: IndexSet(integer: from), to: destination)
    }

    func renameItem(_ item: CustomDockItem, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].displayName = trimmed
        commitItemChange()
    }

    static func makeItem(from url: URL) -> CustomDockItem? {
        if url.isFileURL {
            let isApp = url.pathExtension.lowercased() == "app"
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let type: CustomDockItemType = isApp ? .app : (isDirectory ? .folder : .file)
            let displayName = url.deletingPathExtension().lastPathComponent
            return CustomDockItem(type: type, path: url.path, displayName: displayName)
        }
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return nil }
        return CustomDockItem(type: .url, path: url.absoluteString, displayName: url.host ?? url.absoluteString)
    }

    // MARK: - App State

    func isRunning(_ item: CustomDockItem) -> Bool {
        guard item.type == .app, let bundleID = item.bundleIdentifier else { return false }
        return runningAppsMonitor.isRunning(bundleID: bundleID)
    }

    func icon(for item: CustomDockItem) -> NSImage {
        iconResolver.icon(for: item)
    }

    // MARK: - Actions

    func launchItem(_ item: CustomDockItem) {
        launchService.launch(item: item)
    }

    func revealInFinder(_ item: CustomDockItem) {
        launchService.revealInFinder(item: item)
    }

    // MARK: - Private Helpers

    private func insert(_ newItems: [CustomDockItem], at index: Int) {
        items.insert(contentsOf: newItems, at: min(max(index, 0), items.count))
        commitItemChange()
    }

    private func commitItemChange() {
        for index in items.indices {
            items[index].sortOrder = index
        }
        saveConfiguration()
        onItemsChanged?()
    }
}
