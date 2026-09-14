import XCTest
@testable import ExtraDockKit

final class CustomDockLayoutTests: XCTestCase {
    private func layout(
        edge: DockEdge = .bottom,
        count: Int = 3,
        iconSize: CGFloat = 64,
        spacing: CGFloat = 8,
        labels: Bool = false,
        magnification: CGFloat = 1,
        available: CGFloat = .greatestFiniteMagnitude
    ) -> CustomDockLayout {
        CustomDockLayout(
            edge: edge, itemCount: count, iconSize: iconSize, spacing: spacing,
            showLabels: labels, magnification: magnification, availableLength: available
        )
    }

    // MARK: Sizes

    func testBottomDock_barSize() {
        let layout = layout()
        // 3 cells of 64 + 2 gaps of 8 + padding 8 on both ends
        XCTAssertEqual(layout.barSize.width, 3 * 64 + 2 * 8 + 16)
        // icon + indicator gap and dot + padding
        XCTAssertEqual(layout.barSize.height, 64 + 3 + 5 + 16)
        XCTAssertEqual(layout.panelSize, layout.barSize)
    }

    func testSideDock_barRunsVertically() {
        let layout = layout(edge: .left)
        XCTAssertEqual(layout.barSize.width, 64 + 3 + 5 + 16)
        XCTAssertEqual(layout.barSize.height, 3 * 64 + 2 * 8 + 16)
    }

    func testLabelsAddRoom() {
        let plain = layout()
        let labeled = layout(labels: true)
        XCTAssertEqual(labeled.cellSize.height - plain.cellSize.height, CustomDockLayout.labelGap + CustomDockLayout.labelHeight)
        XCTAssertEqual(labeled.cellSize.width - plain.cellSize.width, CustomDockLayout.labelExtraWidth)
    }

    func testEmptyDockUsesEmptyStateSize() {
        let layout = layout(count: 0, magnification: 2)
        XCTAssertEqual(layout.barSize, CustomDockLayout.emptySize)
        XCTAssertEqual(layout.panelSize, CustomDockLayout.emptySize)
    }

    // MARK: Magnification

    func testMagnificationReservesRoomAwayFromEdge() {
        let layout = layout(magnification: 2)
        XCTAssertEqual(layout.outwardOverflow, 64)
        XCTAssertEqual(layout.endOverflow, 24) // 64 / 2 - padding
        XCTAssertEqual(layout.panelSize.height, layout.barSize.height + 64)
        XCTAssertEqual(layout.panelSize.width, layout.barSize.width + 48)
    }

    func testBarFrameStaysAgainstTheEdge() {
        let bottom = layout(magnification: 2)
        XCTAssertEqual(bottom.barFrameInPanel.minY, 0)
        XCTAssertEqual(bottom.barFrameInPanel.midX, bottom.panelSize.width / 2)

        let left = layout(edge: .left, magnification: 2)
        XCTAssertEqual(left.barFrameInPanel.minX, 0)

        let right = layout(edge: .right, magnification: 2)
        XCTAssertEqual(right.barFrameInPanel.maxX, right.panelSize.width)
        XCTAssertEqual(right.barFrameInPanel.midY, right.panelSize.height / 2)
    }

    // MARK: Fitting

    func testShrinksIconsToFitScreen() {
        let layout = layout(count: 20, iconSize: 128, magnification: 1.5, available: 1512)
        XCTAssertLessThan(layout.iconSize, 128)
        XCTAssertLessThanOrEqual(layout.panelSize.width, 1512)
    }

    func testKeepsRequestedSizeWhenItFits() {
        XCTAssertEqual(layout(count: 5, iconSize: 96, available: 1512).iconSize, 96)
    }

    func testNeverShrinksBelowMinimum() {
        XCTAssertEqual(layout(count: 500, available: 800).iconSize, CustomDockLayout.minimumIconSize)
    }

    // MARK: Drops

    func testInsertionIndex_bottomDock() {
        let layout = layout() // cells start at x = 8, step 72
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 0, y: 20)), 0)
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 30, y: 20)), 0)   // left half of first icon
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 50, y: 20)), 1)   // right half of first icon
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 130, y: 20)), 2)
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 500, y: 20)), 3)
    }

    func testInsertionIndex_sideDockCountsFromTop() {
        let layout = layout(edge: .right)
        let top = layout.panelSize.height
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 20, y: top - 5)), 0)
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 20, y: 5)), 3)
    }

    func testInsertionIndex_accountsForMagnificationMargin() {
        let layout = layout(magnification: 2) // bar starts 24pt into the panel
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 24 + 30, y: 20)), 0)
        XCTAssertEqual(layout.insertionIndex(at: CGPoint(x: 24 + 50, y: 20)), 1)
    }

    func testInsertionIndex_emptyDock() {
        XCTAssertEqual(layout(count: 0).insertionIndex(at: CGPoint(x: 100, y: 50)), 0)
    }

    func testInsertionMarkerOffset() {
        let layout = layout()
        XCTAssertEqual(layout.insertionMarkerOffset(for: 0), 4)          // middle of leading padding
        XCTAssertEqual(layout.insertionMarkerOffset(for: 1), 8 + 72 - 4) // middle of first gap
        XCTAssertEqual(layout.insertionMarkerOffset(for: 99), layout.insertionMarkerOffset(for: 3))
    }
}
