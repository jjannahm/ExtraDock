import XCTest
@testable import ExtraDockKit

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

    func testDockOrientationMapping() {
        XCTAssertEqual(DockEdge(dockOrientation: "left"), .left)
        XCTAssertEqual(DockEdge(dockOrientation: "right"), .right)
        XCTAssertEqual(DockEdge(dockOrientation: "bottom"), .bottom)
        XCTAssertEqual(DockEdge(dockOrientation: nil), .bottom)
        XCTAssertEqual(DockEdge(dockOrientation: "top"), .bottom)
    }
}

// MARK: - DockGeometryTests

final class DockGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testOrigin_bottomEdge() {
        let origin = DockGeometry.origin(edge: .bottom, size: CGSize(width: 400, height: 80), in: screen)
        XCTAssertEqual(origin.x, 760, accuracy: 0.5) // midX - width/2
        XCTAssertEqual(origin.y, 0, accuracy: 0.5)
    }

    func testOrigin_leftEdge() {
        let origin = DockGeometry.origin(edge: .left, size: CGSize(width: 80, height: 400), in: screen)
        XCTAssertEqual(origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(origin.y, 340, accuracy: 0.5) // midY - height/2
    }

    func testOrigin_rightEdge() {
        let origin = DockGeometry.origin(edge: .right, size: CGSize(width: 80, height: 400), in: screen)
        XCTAssertEqual(origin.x, 1840, accuracy: 0.5) // maxX - width
        XCTAssertEqual(origin.y, 340, accuracy: 0.5)
    }

    func testOrigin_withPositiveOffset() {
        let origin = DockGeometry.origin(edge: .bottom, size: CGSize(width: 400, height: 80), in: screen, offset: 100)
        XCTAssertEqual(origin.x, 860, accuracy: 0.5) // 760 + 100
    }

    func testOrigin_withNegativeOffsetOnSideEdge() {
        let origin = DockGeometry.origin(edge: .left, size: CGSize(width: 80, height: 400), in: screen, offset: -100)
        XCTAssertEqual(origin.y, 240, accuracy: 0.5)
    }

    func testOrigin_insetMovesAwayFromEdge() {
        let size = CGSize(width: 80, height: 400)
        XCTAssertEqual(DockGeometry.origin(edge: .bottom, size: size, in: screen, inset: 50).y, 50, accuracy: 0.5)
        XCTAssertEqual(DockGeometry.origin(edge: .left, size: size, in: screen, inset: 50).x, 50, accuracy: 0.5)
        XCTAssertEqual(DockGeometry.origin(edge: .right, size: size, in: screen, inset: 50).x, 1790, accuracy: 0.5)
    }

    func testOrigin_clampsHugeOffsetsOnScreen() {
        let size = CGSize(width: 400, height: 80)
        XCTAssertEqual(DockGeometry.origin(edge: .bottom, size: size, in: screen, offset: 5000).x, 1520, accuracy: 0.5)
        XCTAssertEqual(DockGeometry.origin(edge: .bottom, size: size, in: screen, offset: -5000).x, 0, accuracy: 0.5)
    }

    func testOrigin_respectsVisibleFrameOrigin() {
        // A second display to the right, with a menu bar and Dock shrinking its visible frame.
        let visible = CGRect(x: 1920, y: 70, width: 2560, height: 1340)
        let origin = DockGeometry.origin(edge: .bottom, size: CGSize(width: 560, height: 80), in: visible)
        XCTAssertEqual(origin.x, 1920 + 1000, accuracy: 0.5)
        XCTAssertEqual(origin.y, 70, accuracy: 0.5)
    }

    func testIsPointNearEdge() {
        XCTAssertTrue(DockGeometry.isPoint(CGPoint(x: 900, y: 0), near: .bottom, of: screen, band: 8))
        XCTAssertTrue(DockGeometry.isPoint(CGPoint(x: 900, y: 8), near: .bottom, of: screen, band: 8))
        XCTAssertFalse(DockGeometry.isPoint(CGPoint(x: 900, y: 9), near: .bottom, of: screen, band: 8))
        XCTAssertTrue(DockGeometry.isPoint(CGPoint(x: 0, y: 500), near: .left, of: screen, band: 8))
        XCTAssertTrue(DockGeometry.isPoint(CGPoint(x: 1920, y: 500), near: .right, of: screen, band: 8))
        XCTAssertFalse(DockGeometry.isPoint(CGPoint(x: 1900, y: 500), near: .right, of: screen, band: 8))
    }

    func testIsPointNearEdge_ignoresOtherDisplays() {
        // Directly below this screen, on a different display.
        XCTAssertFalse(DockGeometry.isPoint(CGPoint(x: 900, y: -5), near: .bottom, of: screen, band: 8))
    }

    func testHiddenFrameSlidesPastTheEdge() {
        let frame = CGRect(x: 100, y: 0, width: 400, height: 80)
        XCTAssertEqual(DockGeometry.hiddenFrame(for: frame, edge: .bottom), CGRect(x: 100, y: -80, width: 400, height: 80))
        let side = CGRect(x: 1416, y: 100, width: 96, height: 752)
        XCTAssertEqual(DockGeometry.hiddenFrame(for: side, edge: .right).minX, 1512)
        XCTAssertEqual(DockGeometry.hiddenFrame(for: CGRect(x: 0, y: 100, width: 96, height: 752), edge: .left).maxX, 0)
    }

    func testOutwardDistance() {
        let start = CGPoint(x: 1000, y: 100)
        XCTAssertEqual(DockGeometry.outwardDistance(from: start, to: CGPoint(x: 1000, y: 130), edge: .bottom), 30)
        XCTAssertEqual(DockGeometry.outwardDistance(from: start, to: CGPoint(x: 1030, y: 100), edge: .left), 30)
        // Dragging a right-edge dock's inner edge to the left makes it bigger.
        XCTAssertEqual(DockGeometry.outwardDistance(from: start, to: CGPoint(x: 970, y: 100), edge: .right), 30)
    }

    func testAvailableLength() {
        XCTAssertEqual(DockGeometry.availableLength(along: .bottom, in: screen), 1920)
        XCTAssertEqual(DockGeometry.availableLength(along: .left, in: screen), 1080)
    }
}
