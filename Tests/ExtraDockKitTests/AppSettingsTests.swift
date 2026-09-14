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

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: defaults, notificationCenter: center)
    }

    func testDefaults() {
        let settings = makeSettings()
        XCTAssertTrue(settings.mirrorEnabled)
        XCTAssertEqual(settings.mirrorScale, 1.0)
        XCTAssertFalse(settings.mirrorAutoHide)
        XCTAssertEqual(settings.mirrorAutoHideDelay, 5)
        XCTAssertTrue(settings.customEnabled)
        XCTAssertEqual(settings.customDisplay, "")
        XCTAssertEqual(settings.customEdge, .bottom)
        XCTAssertEqual(settings.customIconSize, 64)
        XCTAssertEqual(settings.customIconSpacing, 8)
        XCTAssertEqual(settings.customOpacity, 1.0)
        XCTAssertFalse(settings.customMagnification)
        XCTAssertEqual(settings.customMagnificationScale, 1.5)
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
}
