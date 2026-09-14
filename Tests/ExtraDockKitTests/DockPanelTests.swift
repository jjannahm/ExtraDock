import AppKit
import XCTest
@testable import ExtraDockKit

/// Exercises show/hide state on a real panel placed far away from any display,
/// so the real pointer can never be over it or at its edge.
@MainActor
final class DockPanelTests: XCTestCase {
    private let farScreen = CGRect(x: -60_000, y: -60_000, width: 1512, height: 982)
    private var farFrame: CGRect { CGRect(x: farScreen.midX - 200, y: farScreen.minY, width: 400, height: 80) }
    private var panel: DockPanel!

    override func setUp() {
        super.setUp()
        panel = DockPanel(showsOverFullScreenApps: false)
    }

    override func tearDown() {
        panel.close()
        panel = nil
        super.tearDown()
    }

    private func place(_ visibility: DockVisibility) {
        panel.update(frame: farFrame, edge: .bottom, screenFrame: farScreen, visibility: visibility)
    }

    private func wait(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testPinnedDockShowsAtItsFrame() {
        place(.pinned)
        XCTAssertTrue(panel.isRevealed)
        XCTAssertEqual(panel.frame, farFrame)
    }

    func testAutoHidingDockStartsHidden() {
        place(.autoHide)
        XCTAssertFalse(panel.isRevealed)
        XCTAssertFalse(panel.isVisible)
    }

    func testEmptyDockStartsHidden() {
        place(.revealWhileDragging)
        XCTAssertFalse(panel.isRevealed)
    }

    func testTurningOnAutoHideHidesOnceThePointerIsAway() {
        place(.pinned)
        place(.autoHide)
        XCTAssertTrue(panel.isRevealed, "hides after a short delay, not instantly")
        wait(DockPanel.hideDelay + 0.3)
        XCTAssertFalse(panel.isRevealed)
    }

    func testTurningOffAutoHideShowsTheDock() {
        place(.autoHide)
        place(.pinned)
        XCTAssertTrue(panel.isRevealed)
    }

    func testDockNeverHidesDuringAnInteraction() {
        place(.pinned)
        panel.beginInteraction()
        place(.autoHide)
        wait(DockPanel.hideDelay + 0.3)
        XCTAssertTrue(panel.isRevealed)

        panel.endInteraction()
        wait(DockPanel.hideDelay + 0.3)
        XCTAssertFalse(panel.isRevealed)
    }

    func testPeekShowsAHiddenDockThenHidesIt() {
        place(.autoHide)
        panel.peek()
        XCTAssertTrue(panel.isRevealed)
        wait(2.0)
        XCTAssertFalse(panel.isRevealed)
    }

    func testMovingAHiddenDockKeepsItHidden() {
        place(.autoHide)
        panel.update(frame: farFrame.offsetBy(dx: 50, dy: 0), edge: .bottom, screenFrame: farScreen, visibility: .autoHide)
        XCTAssertFalse(panel.isRevealed)
        XCTAssertEqual(panel.targetFrame, farFrame.offsetBy(dx: 50, dy: 0))
    }
}
