import AppKit
import XCTest
@testable import ExtraDockKit

// MARK: - DockConfigReaderTests

final class DockConfigReaderTests: XCTestCase {
    private func appTile(_ label: String, bundle: String, path: String) -> [String: Any] {
        [
            "tile-type": "file-tile",
            "tile-data": [
                "file-label": label,
                "bundle-identifier": bundle,
                "file-data": ["_CFURLString": "file://\(path)/", "_CFURLStringType": 15]
            ]
        ]
    }

    private func folderTile(_ label: String, path: String) -> [String: Any] {
        [
            "tile-type": "directory-tile",
            "tile-data": [
                "file-label": label,
                "file-data": ["_CFURLString": "file://\(path)/", "_CFURLStringType": 15]
            ]
        ]
    }

    private func plistData(_ plist: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    private var samplePlist: [String: Any] {
        [
            "tilesize": 64,
            "orientation": "left",
            "persistent-apps": [
                appTile("Safari", bundle: "com.apple.Safari", path: "/Applications/Safari.app"),
                ["tile-type": "spacer-tile", "tile-data": [:] as [String: Any]],
                appTile("Google Chrome", bundle: "com.google.Chrome", path: "/Applications/Google%20Chrome.app")
            ],
            "recent-apps": [appTile("Notes", bundle: "com.apple.Notes", path: "/System/Applications/Notes.app")],
            "persistent-others": [folderTile("Downloads", path: "/Users/test/Downloads")]
        ]
    }

    func testParse_readsSectionsInOrder() throws {
        let config = DockConfigReader.parse(data: try plistData(samplePlist))
        XCTAssertEqual(config.items.map(\.name), ["Safari", "Google Chrome", "Notes", "Downloads"])
        XCTAssertEqual(config.items.map(\.section), [.pinnedApps, .pinnedApps, .recentApps, .persistentOthers])
    }

    func testParse_readsAppDetails() throws {
        let chrome = DockConfigReader.parse(data: try plistData(samplePlist)).items[1]
        XCTAssertEqual(chrome.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(chrome.path, "/Applications/Google Chrome.app")
        XCTAssertNil(DockConfigReader.parse(data: try plistData(samplePlist)).items[3].bundleIdentifier)
    }

    func testParse_readsTileSizeAndOrientation() throws {
        let config = DockConfigReader.parse(data: try plistData(samplePlist))
        XCTAssertEqual(config.tileSize, 64)
        XCTAssertEqual(config.edge, .left)
    }

    func testParse_readsAutoHide() throws {
        XCTAssertFalse(DockConfigReader.parse(data: try plistData(samplePlist)).autoHides)
        var plist = samplePlist
        plist["autohide"] = true
        XCTAssertTrue(DockConfigReader.parse(data: try plistData(plist)).autoHides)
    }

    func testParse_acceptsRealTileSize() throws {
        var plist = samplePlist
        plist["tilesize"] = 47.5
        XCTAssertEqual(DockConfigReader.parse(data: try plistData(plist)).tileSize, 47.5)
    }

    func testParse_hidesRecentAppsWhenDockDoes() throws {
        var plist = samplePlist
        plist["show-recents"] = false
        let config = DockConfigReader.parse(data: try plistData(plist))
        XCTAssertFalse(config.items.contains { $0.section == .recentApps })
        XCTAssertEqual(config.items.count, 3)
    }

    func testParse_defaultsWhenKeysMissing() throws {
        let config = DockConfigReader.parse(data: try plistData([:]))
        XCTAssertTrue(config.items.isEmpty)
        XCTAssertEqual(config.tileSize, DockConfigReader.defaultTileSize)
        XCTAssertEqual(config.edge, .bottom)
    }

    func testParse_invalidDataReturnsEmpty() {
        let config = DockConfigReader.parse(data: Data("not a plist".utf8))
        XCTAssertTrue(config.items.isEmpty)
    }

    func testParse_missingFileReturnsEmpty() {
        let config = DockConfigReader.parse(url: URL(fileURLWithPath: "/nonexistent/com.apple.dock.plist"))
        XCTAssertTrue(config.items.isEmpty)
    }
}

// MARK: - MirrorDockStateTests

@MainActor
final class MirrorDockStateTests: XCTestCase {
    private func item(
        _ name: String, bundle: String? = nil, path: String? = nil, section: MirrorDockSection = .pinnedApps
    ) -> MirrorDockItem {
        MirrorDockItem(name: name, bundleIdentifier: bundle, path: path ?? "/\(name)", icon: NSImage(), section: section)
    }

    func testUpdateRunningApps_setsFlagsByBundleID() {
        let state = MirrorDockState()
        state.items = [item("Safari", bundle: "com.apple.Safari"), item("Mail", bundle: "com.apple.mail"), item("Docs")]
        state.updateRunningApps(["com.apple.mail"])
        XCTAssertEqual(state.items.map(\.isRunning), [false, true, false])
    }

    func testUpdateItems_keepsRunningStateByPath() {
        let state = MirrorDockState()
        state.items = [item("Mail", bundle: "com.apple.mail")]
        state.updateRunningApps(["com.apple.mail"])
        state.updateItems([item("Mail", bundle: "com.apple.mail"), item("Notes", bundle: "com.apple.Notes")])
        XCTAssertEqual(state.items.map(\.isRunning), [true, false])
    }

    func testUpdateItems_toleratesDuplicatePaths() {
        let state = MirrorDockState()
        state.items = [item("Downloads", path: "/d"), item("Downloads", path: "/d")]
        state.updateItems([item("Downloads", path: "/d"), item("Downloads", path: "/d")])
        XCTAssertEqual(state.items.count, 2)
    }

    func testUpdateBadges_matchesByName() {
        let state = MirrorDockState()
        state.items = [item("Mail"), item("Messages")]
        state.updateBadges(["Mail": "3"])
        XCTAssertEqual(state.items.map(\.badgeCount), ["3", nil])
    }

    func testSeparatorCount() {
        let state = MirrorDockState()
        XCTAssertEqual(state.separatorCount, 0)
        state.items = [item("A")]
        XCTAssertEqual(state.separatorCount, 0)
        state.items = [item("A"), item("Downloads", section: .persistentOthers)]
        XCTAssertEqual(state.separatorCount, 1)
        state.items = [item("A"), item("B", section: .recentApps), item("C", section: .persistentOthers)]
        XCTAssertEqual(state.separatorCount, 2)
    }

    func testApply_copiesConfiguration() {
        let state = MirrorDockState()
        state.apply(SystemDockConfiguration(items: [item("A")], tileSize: 80, edge: .right))
        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.tileSize, 80)
        XCTAssertEqual(state.edge, .right)
    }
}

// MARK: - MirrorDockLayoutTests

final class MirrorDockLayoutTests: XCTestCase {
    func testPanelSize_bottomDock() {
        // Matches extradock's original sizing: items + separators + padding on both ends.
        let layout = MirrorDockLayout(edge: .bottom, itemCount: 9, separatorCount: 1, baseTileSize: 49, scale: 1)
        XCTAssertEqual(layout.panelSize.width, 9 * 49 + 12 + 32)
        XCTAssertEqual(layout.panelSize.height, 49 + 16)
    }

    func testPanelSize_sideDockSwapsAxes() {
        let layout = MirrorDockLayout(edge: .right, itemCount: 4, separatorCount: 0, baseTileSize: 80, scale: 1)
        XCTAssertEqual(layout.panelSize.width, 96)
        XCTAssertEqual(layout.panelSize.height, 4 * 80 + 32)
    }

    func testScaleAppliesToTilesAndPadding() {
        let layout = MirrorDockLayout(edge: .bottom, itemCount: 2, separatorCount: 0, baseTileSize: 50, scale: 2)
        XCTAssertEqual(layout.tileSize, 100)
        XCTAssertEqual(layout.panelSize.height, 100 + 32)
    }

    func testShrinksTilesToFitScreen() {
        let layout = MirrorDockLayout(
            edge: .bottom, itemCount: 30, separatorCount: 2, baseTileSize: 80, scale: 1, availableLength: 1440
        )
        XCTAssertLessThan(layout.tileSize, 80)
        XCTAssertLessThanOrEqual(layout.panelSize.width, 1440)
    }
}

// MARK: - DockMenuProxyTests

final class DockMenuProxyTests: XCTestCase {
    func testIndexToPress_usesCachedIndexWhenTitleMatches() {
        XCTAssertEqual(DockMenuProxy.indexToPress(title: "Quit", preferredIndex: 2, in: ["Open", "Hide", "Quit"]), 2)
    }

    func testIndexToPress_findsMovedItemByTitle() {
        XCTAssertEqual(DockMenuProxy.indexToPress(title: "Quit", preferredIndex: 1, in: ["Options", "Show", "Quit"]), 2)
    }

    func testIndexToPress_nilWhenItemIsGone() {
        // E.g. "Quit" was cached while the app ran, but the app has since quit.
        XCTAssertNil(DockMenuProxy.indexToPress(title: "Quit", preferredIndex: 2, in: ["Options", "Open"]))
    }
}

// MARK: - SystemDockLocatorTests

final class SystemDockLocatorTests: XCTestCase {
    // A 1512×982 laptop screen with a 1920×1080 display to its right, 98pt lower.
    private let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let external = CGRect(x: 1512, y: -98, width: 1920, height: 1080)

    func testFindsDisplayUnderDockWindow() {
        // The Dock's window as CoreGraphics reports it (top-left origin).
        let dockWindow = CGRect(x: 1512, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(SystemDockLocator.screenIndex(forDockWindow: dockWindow, screenFrames: [laptop, external]), 1)
    }

    func testFindsMainDisplay() {
        let dockWindow = CGRect(x: 0, y: 0, width: 1512, height: 982)
        XCTAssertEqual(SystemDockLocator.screenIndex(forDockWindow: dockWindow, screenFrames: [laptop, external]), 0)
    }

    func testWindowOffAllDisplays() {
        let dockWindow = CGRect(x: -5000, y: -5000, width: 100, height: 100)
        XCTAssertNil(SystemDockLocator.screenIndex(forDockWindow: dockWindow, screenFrames: [laptop, external]))
    }

    func testFallbackUsesOutermostDisplayForSideDocks() {
        let frames = [laptop, external]
        XCTAssertEqual(SystemDockLocator.fallbackScreenIndex(orientation: .right, screenFrames: frames), 1)
        XCTAssertEqual(SystemDockLocator.fallbackScreenIndex(orientation: .left, screenFrames: frames), 0)
        XCTAssertEqual(SystemDockLocator.fallbackScreenIndex(orientation: .bottom, screenFrames: frames), 0)
        XCTAssertNil(SystemDockLocator.fallbackScreenIndex(orientation: .bottom, screenFrames: []))
    }
}
