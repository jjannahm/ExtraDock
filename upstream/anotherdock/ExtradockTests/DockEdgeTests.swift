import XCTest
@testable import Extradock

final class DockEdgeTests: XCTestCase {
    func testAllCases() {
        XCTAssertEqual(DockEdge.allCases.count, 3)
        XCTAssertTrue(DockEdge.allCases.contains(.left))
        XCTAssertTrue(DockEdge.allCases.contains(.right))
        XCTAssertTrue(DockEdge.allCases.contains(.bottom))
    }

    func testRawValues() {
        XCTAssertEqual(DockEdge.left.rawValue, "left")
        XCTAssertEqual(DockEdge.right.rawValue, "right")
        XCTAssertEqual(DockEdge.bottom.rawValue, "bottom")
    }

    func testLocalizedNames() {
        XCTAssertEqual(DockEdge.left.localizedName, "Left")
        XCTAssertEqual(DockEdge.right.localizedName, "Right")
        XCTAssertEqual(DockEdge.bottom.localizedName, "Bottom")
    }

    func testCodable_roundTrip() throws {
        for edge in DockEdge.allCases {
            let data = try JSONEncoder().encode(edge)
            let decoded = try JSONDecoder().decode(DockEdge.self, from: data)
            XCTAssertEqual(decoded, edge)
        }
    }
}

// MARK: - MainWindowControllerPositionTests

@MainActor
final class MainWindowControllerPositionTests: XCTestCase {
    private var controller: MainWindowController!

    override func setUp() {
        super.setUp()
        let dockVM = DockViewModel(
            persistenceService: MockPersistenceService(),
            runningAppsMonitor: RunningAppsMonitor(),
            launchService: LaunchService(),
            iconResolver: AppIconResolver()
        )
        let settingsVM = SettingsViewModel()
        controller = MainWindowController(dockViewModel: dockVM, settingsViewModel: settingsVM)
    }

    override func tearDown() {
        controller = nil
        super.tearDown()
    }

    func testWindowOrigin_bottomEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = CGSize(width: 400, height: 80)
        let origin = controller.windowOrigin(
            edge: .bottom,
            offset: 0,
            screenFrame: screen,
            windowSize: windowSize
        )
        XCTAssertEqual(origin.x, 760, accuracy: 0.5) // midX - width/2
        XCTAssertEqual(origin.y, 0, accuracy: 0.5)
    }

    func testWindowOrigin_leftEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = CGSize(width: 80, height: 400)
        let origin = controller.windowOrigin(
            edge: .left,
            offset: 0,
            screenFrame: screen,
            windowSize: windowSize
        )
        XCTAssertEqual(origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(origin.y, 340, accuracy: 0.5) // midY - height/2
    }

    func testWindowOrigin_rightEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = CGSize(width: 80, height: 400)
        let origin = controller.windowOrigin(
            edge: .right,
            offset: 0,
            screenFrame: screen,
            windowSize: windowSize
        )
        XCTAssertEqual(origin.x, 1840, accuracy: 0.5) // maxX - width
        XCTAssertEqual(origin.y, 340, accuracy: 0.5)
    }

    func testWindowOrigin_withPositiveOffset() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = CGSize(width: 400, height: 80)
        let origin = controller.windowOrigin(
            edge: .bottom,
            offset: 100,
            screenFrame: screen,
            windowSize: windowSize
        )
        XCTAssertEqual(origin.x, 860, accuracy: 0.5) // 760 + 100
    }
}
