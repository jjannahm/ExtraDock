// DockConfigReader.swift
import Foundation
import AppKit

// MARK: - SystemDockConfiguration

struct SystemDockConfiguration {
    var items: [MirrorDockItem]
    var tileSize: CGFloat
    var edge: DockEdge

    static let empty = SystemDockConfiguration(items: [], tileSize: DockConfigReader.defaultTileSize, edge: .bottom)
}

// MARK: - DockConfigReader

struct DockConfigReader {
    static let defaultTileSize: CGFloat = 49

    static var plistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist")
    }

    /// Parses the macOS Dock preferences plist and returns the items and display settings.
    /// If the plist cannot be read, returns empty items with default tileSize/orientation.
    static func parse(url: URL = plistURL) -> SystemDockConfiguration {
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return parse(data: data)
    }

    static func parse(data: Data) -> SystemDockConfiguration {
        guard
            let raw = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let plist = raw as? [String: Any]
        else {
            return .empty
        }

        // The Dock stores tilesize as an integer or a real depending on how it was set.
        let tileSize = CGFloat((plist["tilesize"] as? NSNumber)?.doubleValue ?? Double(defaultTileSize))
        let edge = DockEdge(dockOrientation: plist["orientation"] as? String)
        let showsRecents = (plist["show-recents"] as? NSNumber)?.boolValue ?? true

        var items: [MirrorDockItem] = []

        // persistent-apps
        if let persistentApps = plist["persistent-apps"] as? [[String: Any]] {
            for entry in persistentApps {
                if let item = parsePersistentApp(entry, section: .pinnedApps) {
                    items.append(item)
                }
            }
        }

        // recent-apps (the Dock keeps this list even when "Show suggested and
        // recent apps" is off, but doesn't display it)
        if showsRecents, let recentApps = plist["recent-apps"] as? [[String: Any]] {
            for entry in recentApps {
                if let item = parsePersistentApp(entry, section: .recentApps) {
                    items.append(item)
                }
            }
        }

        // persistent-others (folders, files)
        if let persistentOthers = plist["persistent-others"] as? [[String: Any]] {
            for entry in persistentOthers {
                if let item = parsePersistentOther(entry) {
                    items.append(item)
                }
            }
        }

        return SystemDockConfiguration(items: items, tileSize: tileSize, edge: edge)
    }

    // MARK: - Private helpers

    /// Parses a persistent-apps or recent-apps entry.
    private static func parsePersistentApp(_ entry: [String: Any], section: MirrorDockSection) -> MirrorDockItem? {
        guard
            let tileData = entry["tile-data"] as? [String: Any],
            let fileData = tileData["file-data"] as? [String: Any],
            let urlString = fileData["_CFURLString"] as? String,
            let url = URL(string: urlString)
        else {
            return nil
        }

        let path = url.path
        let name = (tileData["file-label"] as? String) ?? url.deletingPathExtension().lastPathComponent
        let bundleIdentifier = tileData["bundle-identifier"] as? String
        let icon = NSWorkspace.shared.icon(forFile: path)

        return MirrorDockItem(
            name: name,
            bundleIdentifier: bundleIdentifier,
            path: path,
            icon: icon,
            section: section
        )
    }

    /// Parses a persistent-others entry (folders, stacks, files).
    private static func parsePersistentOther(_ entry: [String: Any]) -> MirrorDockItem? {
        guard
            let tileData = entry["tile-data"] as? [String: Any],
            let fileData = tileData["file-data"] as? [String: Any],
            let urlString = fileData["_CFURLString"] as? String,
            let url = URL(string: urlString)
        else {
            return nil
        }

        let path = url.path
        let name = (tileData["file-label"] as? String) ?? url.lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: path)

        return MirrorDockItem(
            name: name,
            bundleIdentifier: nil,
            path: path,
            icon: icon,
            section: .persistentOthers
        )
    }
}
