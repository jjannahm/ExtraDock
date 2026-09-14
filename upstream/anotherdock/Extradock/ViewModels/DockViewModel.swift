import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - DockViewModel

@MainActor
final class DockViewModel: ObservableObject {
    @Published private(set) var items: [DockItem] = []
    @Published private(set) var groups: [DockGroup] = []
    @Published var isVisible: Bool = true

    private let persistenceService: any PersistenceServiceProtocol
    let runningAppsMonitor: RunningAppsMonitor
    let launchService: LaunchService
    let iconResolver: AppIconResolver

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

    // Convenience init for production — creates default services on the main actor
    convenience init() {
        self.init(
            persistenceService: PersistenceService.shared,
            runningAppsMonitor: RunningAppsMonitor(),
            launchService: LaunchService(),
            iconResolver: AppIconResolver()
        )
    }

    // MARK: - Configuration

    func loadConfiguration() {
        do {
            let config = try persistenceService.load()
            items = config.items.sorted { $0.sortOrder < $1.sortOrder }
            groups = config.groups
        } catch {
            print("Failed to load dock configuration: \(error.localizedDescription)")
            items = []
            groups = []
        }
    }

    func saveConfiguration() {
        let config = DockConfiguration(items: items, groups: groups)
        do {
            try persistenceService.save(config)
        } catch {
            print("Failed to save dock configuration: \(error.localizedDescription)")
        }
    }

    // MARK: - Item Management

    func addItem(_ item: DockItem) {
        var newItem = item
        newItem.sortOrder = items.count
        items.append(newItem)
        saveConfiguration()
    }

    func addItemFromURL(_ url: URL) {
        let isApp = url.pathExtension.lowercased() == "app"
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let type: DockItemType = isApp ? .app : (isDirectory ? .folder : .file)
        let displayName = url.deletingPathExtension().lastPathComponent
        let item = DockItem(type: type, path: url.path, displayName: displayName)
        addItem(item)
    }

    func removeItem(_ item: DockItem) {
        items.removeAll { $0.id == item.id }
        reindexSortOrders()
        saveConfiguration()
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        reindexSortOrders()
        saveConfiguration()
    }

    func renameItem(_ item: DockItem, to name: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].displayName = name
        saveConfiguration()
    }

    // MARK: - App State

    func isRunning(_ item: DockItem) -> Bool {
        guard item.type == .app, let bundleID = item.bundleIdentifier else { return false }
        return runningAppsMonitor.isRunning(bundleID: bundleID)
    }

    func icon(for item: DockItem) -> NSImage {
        iconResolver.icon(for: item)
    }

    // MARK: - Actions

    func launchItem(_ item: DockItem) {
        launchService.launch(item: item)
    }

    func revealInFinder(_ item: DockItem) {
        launchService.revealInFinder(item: item)
    }

    func toggleVisibility() {
        isVisible.toggle()
    }

    // MARK: - Private Helpers

    private func reindexSortOrders() {
        for index in items.indices {
            items[index].sortOrder = index
        }
    }
}
