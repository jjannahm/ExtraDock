// MirrorDockState.swift
import Foundation
import Observation

// MARK: - MirrorDockState

/// The system Dock's contents and settings, shared by every Mirror Dock panel.
@MainActor
@Observable
final class MirrorDockState {
    var items: [MirrorDockItem] = []
    var tileSize: CGFloat = 49
    var edge: DockEdge = .bottom

    /// Separators the system Dock draws between non-empty sections.
    var separatorCount: Int {
        let hasPinned = items.contains { $0.section == .pinnedApps }
        let hasRecent = items.contains { $0.section == .recentApps }
        let hasOthers = items.contains { $0.section == .persistentOthers }
        var count = 0
        if hasPinned && (hasRecent || hasOthers) { count += 1 }
        if hasRecent && hasOthers { count += 1 }
        return count
    }

    func apply(_ configuration: SystemDockConfiguration) {
        updateItems(configuration.items)
        tileSize = configuration.tileSize
        edge = configuration.edge
    }

    // Merges new config items with current running state.
    // Items already present (by path) retain their isRunning flag.
    func updateItems(_ newItems: [MirrorDockItem]) {
        // Build a lookup of current running state by path (path is stable across reloads).
        // The same path can appear twice (e.g. a folder pinned twice), so don't assume uniqueness.
        let runningByPath: [String: Bool] = Dictionary(
            items.map { ($0.path, $0.isRunning) },
            uniquingKeysWith: { first, _ in first }
        )

        items = newItems.map { item in
            var updated = item
            if let wasRunning = runningByPath[item.path] {
                updated.isRunning = wasRunning
            }
            return updated
        }
    }

    // Updates the isRunning flag on existing items based on the provided set of bundle IDs.
    func updateRunningApps(_ bundleIDs: Set<String>) {
        items = items.map { item in
            var updated = item
            if let bid = item.bundleIdentifier {
                updated.isRunning = bundleIDs.contains(bid)
            } else {
                updated.isRunning = false
            }
            return updated
        }
    }

    // Updates badge counts from a dictionary keyed by app name.
    func updateBadges(_ badges: [String: String]) {
        items = items.map { item in
            var updated = item
            updated.badgeCount = badges[item.name]
            return updated
        }
    }
}
