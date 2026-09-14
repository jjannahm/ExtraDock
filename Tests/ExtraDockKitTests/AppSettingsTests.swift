import XCTest
@testable import ExtraDockKit

@MainActor
final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var center: NotificationCenter!

    override func setUp() {
        super.setUp()
        suiteName = "ExtraDockTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        center = NotificationCenter()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        center = nil
        super.tearDown()
    }

    private func makeSettings(systemDockAutoHides: Bool = false) -> AppSettings {
        AppSettings(defaults: defaults, notificationCenter: center, systemDockAutoHides: systemDockAutoHides)
    }

    func testDefaults() {
        let settings = makeSettings()
        XCTAssertTrue(settings.mirrorEnabled)
        XCTAssertEqual(settings.mirrorScale, 1.0)
        XCTAssertFalse(settings.mirrorAutoHide)
        XCTAssertFalse(settings.customAutoHide)
        XCTAssertTrue(settings.customEnabled)
        XCTAssertEqual(settings.customDisplay, "")
        XCTAssertEqual(settings.customEdge, .bottom)
        XCTAssertEqual(settings.customIconSize, 64)
        XCTAssertEqual(settings.customIconSpacing, 8)
        XCTAssertEqual(settings.customOpacity, 1.0)
        XCTAssertFalse(settings.customMagnification)
        XCTAssertEqual(settings.customMagnificationScale, 1.5)
    }

    func testAutoHideDefaultsToSystemDockSetting() {
        let settings = makeSettings(systemDockAutoHides: true)
        XCTAssertTrue(settings.mirrorAutoHide)
        XCTAssertTrue(settings.customAutoHide)
    }

    func testChosenAutoHideOverridesSystemDockSetting() {
        makeSettings(systemDockAutoHides: true).customAutoHide = false
        let reloaded = makeSettings(systemDockAutoHides: true)
        XCTAssertFalse(reloaded.customAutoHide)
        XCTAssertTrue(reloaded.mirrorAutoHide)
    }

    func testCustomIconSizeResizing() {
        XCTAssertEqual(AppSettings.customIconSize(resizingFrom: 64, by: 20), 84)
        XCTAssertEqual(AppSettings.customIconSize(resizingFrom: 64, by: -10.4), 54)
        XCTAssertEqual(AppSettings.customIconSize(resizingFrom: 64, by: 500), AppSettings.iconSizeRange.upperBound)
        XCTAssertEqual(AppSettings.customIconSize(resizingFrom: 64, by: -500), AppSettings.iconSizeRange.lowerBound)
    }

    func testMirrorScaleResizingKeepsEdgeUnderPointer() {
        // An 80pt Dock is (80 + 16) × scale deep, so 48pt of drag is half a step of scale.
        XCTAssertEqual(AppSettings.mirrorScale(resizingFrom: 1.0, by: -48, tileSize: 80), 0.5, accuracy: 0.001)
        XCTAssertEqual(AppSettings.mirrorScale(resizingFrom: 1.0, by: 24, tileSize: 80), 1.25, accuracy: 0.001)
        XCTAssertEqual(AppSettings.mirrorScale(resizingFrom: 1.0, by: -1000, tileSize: 80), AppSettings.mirrorScaleRange.lowerBound)
        XCTAssertEqual(AppSettings.mirrorScale(resizingFrom: 1.0, by: 1000, tileSize: 80), AppSettings.mirrorScaleRange.upperBound)
    }

    func testValuesPersistAcrossInstances() {
        let settings = makeSettings()
        settings.customEdge = .right
        settings.customIconSize = 96
        settings.mirrorAutoHide = true
        settings.customDisplay = "DISPLAY-UUID"

        let reloaded = makeSettings()
        XCTAssertEqual(reloaded.customEdge, .right)
        XCTAssertEqual(reloaded.customIconSize, 96)
        XCTAssertTrue(reloaded.mirrorAutoHide)
        XCTAssertEqual(reloaded.customDisplay, "DISPLAY-UUID")
    }

    func testOutOfRangeStoredValuesAreClamped() {
        defaults.set(1000.0, forKey: AppSettings.Keys.customIconSize)
        defaults.set(-3.0, forKey: AppSettings.Keys.mirrorScale)
        defaults.set("diagonal", forKey: AppSettings.Keys.customEdge)
        let settings = makeSettings()
        XCTAssertEqual(settings.customIconSize, AppSettings.iconSizeRange.upperBound)
        XCTAssertEqual(settings.mirrorScale, AppSettings.mirrorScaleRange.lowerBound)
        XCTAssertEqual(settings.customEdge, .bottom)
    }

    func testChangesPostNotification() {
        let settings = makeSettings()
        let posted = expectation(forNotification: .extraDockSettingsChanged, object: settings, notificationCenter: center)
        settings.customOpacity = 0.5
        wait(for: [posted], timeout: 1)
    }

    func testMirrorDisplays_offByDefaultWhereSystemDockIs() {
        let settings = makeSettings()
        XCTAssertFalse(settings.isMirrorEnabled(onDisplay: "main", hasSystemDock: true))
        XCTAssertTrue(settings.isMirrorEnabled(onDisplay: "external", hasSystemDock: false))
    }

    func testMirrorDisplays_choicesPersist() {
        let settings = makeSettings()
        settings.setMirrorEnabled(true, onDisplay: "main")
        settings.setMirrorEnabled(false, onDisplay: "external")

        let reloaded = makeSettings()
        XCTAssertTrue(reloaded.isMirrorEnabled(onDisplay: "main", hasSystemDock: true))
        XCTAssertFalse(reloaded.isMirrorEnabled(onDisplay: "external", hasSystemDock: false))
    }

    // MARK: Only with an external display

    func testExternalDisplayRequirementIsOffByDefault() {
        let settings = makeSettings()
        XCTAssertFalse(settings.mirrorOnlyWithExternalDisplay)
        XCTAssertFalse(settings.customOnlyWithExternalDisplay)
        XCTAssertTrue(settings.isMirrorDockActive(externalDisplayConnected: false))
        XCTAssertTrue(settings.isCustomDockActive(externalDisplayConnected: false))
    }

    func testDockWaitsForExternalDisplayWhenRequired() {
        let settings = makeSettings()
        settings.customOnlyWithExternalDisplay = true
        XCTAssertFalse(settings.isCustomDockActive(externalDisplayConnected: false))
        XCTAssertTrue(settings.isCustomDockActive(externalDisplayConnected: true))
        // The other dock is unaffected.
        XCTAssertTrue(settings.isMirrorDockActive(externalDisplayConnected: false))

        settings.mirrorOnlyWithExternalDisplay = true
        XCTAssertFalse(settings.isMirrorDockActive(externalDisplayConnected: false))
        XCTAssertTrue(settings.isMirrorDockActive(externalDisplayConnected: true))
    }

    func testTurnedOffDockStaysOffEvenWithExternalDisplay() {
        let settings = makeSettings()
        settings.customEnabled = false
        settings.mirrorEnabled = false
        XCTAssertFalse(settings.isCustomDockActive(externalDisplayConnected: true))
        XCTAssertFalse(settings.isMirrorDockActive(externalDisplayConnected: true))
    }

    func testExternalDisplayRequirementPersists() {
        let settings = makeSettings()
        settings.mirrorOnlyWithExternalDisplay = true
        settings.customOnlyWithExternalDisplay = true
        let reloaded = makeSettings()
        XCTAssertTrue(reloaded.mirrorOnlyWithExternalDisplay)
        XCTAssertTrue(reloaded.customOnlyWithExternalDisplay)
    }
}
