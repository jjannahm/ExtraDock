import AppKit
import XCTest
@testable import ExtraDockKit

// MARK: - DockItemInteractionViewTests

@MainActor
final class DockItemInteractionViewTests: XCTestCase {
    private var window: NSWindow!
    private var view: DockItemInteractionView!

    override func setUp() {
        super.setUp()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.borderless], backing: .buffered, defer: true
        )
        view = DockItemInteractionView(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
        window.contentView?.addSubview(view)
    }

    override func tearDown() {
        view = nil
        window = nil
        super.tearDown()
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: modifiers, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        )!
    }

    func testClickInsideFiresOnMouseUp() {
        var clicks = 0
        view.onClick = { clicks += 1 }
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: NSPoint(x: 20, y: 20)))
        XCTAssertEqual(clicks, 0, "launching waits for mouse up so a drag can start instead")
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: NSPoint(x: 22, y: 21)))
        XCTAssertEqual(clicks, 1)
    }

    func testReleasingOutsideCancelsClick() {
        var clicks = 0
        view.onClick = { clicks += 1 }
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: NSPoint(x: 20, y: 20)))
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: NSPoint(x: 90, y: 90)))
        XCTAssertEqual(clicks, 0)
    }

    func testMouseUpWithoutMouseDownIsIgnored() {
        var clicks = 0
        view.onClick = { clicks += 1 }
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: NSPoint(x: 20, y: 20)))
        XCTAssertEqual(clicks, 0)
    }

    func testHoverCallbacks() {
        var states: [Bool] = []
        view.onHover = { states.append($0) }
        view.mouseEntered(with: enterExitEvent(.mouseEntered))
        view.mouseExited(with: enterExitEvent(.mouseExited))
        XCTAssertEqual(states, [true, false])
    }

    private func enterExitEvent(_ type: NSEvent.EventType) -> NSEvent {
        NSEvent.enterExitEvent(
            with: type, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil
        )!
    }

    func testAcceptsFirstMouse() {
        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }
}

// MARK: - CustomDockDropViewTests

@MainActor
final class CustomDockDropViewTests: XCTestCase {
    private func pasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ExtraDockTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }

    func testReorderDrop() {
        let id = UUID()
        let pasteboard = pasteboard()
        let item = NSPasteboardItem()
        item.setString(id.uuidString, forType: CustomDockDropView.itemIDType)
        pasteboard.writeObjects([item])

        guard case let .move(itemID, index)? = CustomDockDropView.drop(from: pasteboard, insertionIndex: 2) else {
            return XCTFail("expected a move")
        }
        XCTAssertEqual(itemID, id)
        XCTAssertEqual(index, 2)
    }

    func testFileDrop() {
        let pasteboard = pasteboard()
        let urls = [URL(fileURLWithPath: "/Applications/Safari.app"), URL(string: "https://example.com")!]
        pasteboard.writeObjects(urls as [NSURL])

        guard case let .add(dropped, index)? = CustomDockDropView.drop(from: pasteboard, insertionIndex: 0) else {
            return XCTFail("expected an add")
        }
        XCTAssertEqual(dropped.map(\.absoluteString), urls.map(\.absoluteString))
        XCTAssertEqual(index, 0)
    }

    func testUnrelatedDropIsRejected() {
        let pasteboard = pasteboard()
        pasteboard.setString("just some text", forType: .string)
        XCTAssertNil(CustomDockDropView.drop(from: pasteboard, insertionIndex: 0))
    }
}
