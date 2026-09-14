import AppKit
import SwiftUI

// MARK: - DockItemInteraction

/// Transparent AppKit overlay for a dock icon. SwiftUI gestures are unreliable in a
/// non-activating panel owned by a background app, so hover, click, right-click
/// menus and drag-out are handled here with an always-active tracking area.
struct DockItemInteraction: NSViewRepresentable {
    var onHover: (Bool) -> Void
    var onClick: () -> Void
    /// Menu shown on right-click (or control-click); nil shows nothing.
    var menu: () -> NSMenu?
    /// Pasteboard contents when the icon is dragged; nil makes the icon non-draggable.
    var dragItem: (() -> NSPasteboardWriting?)?
    var dragImage: NSImage?

    func makeNSView(context: Context) -> DockItemInteractionView {
        let view = DockItemInteractionView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DockItemInteractionView, context: Context) {
        view.onHover = onHover
        view.onClick = onClick
        view.menuProvider = menu
        view.dragItemProvider = dragItem
        view.dragImage = dragImage
    }
}

// MARK: - DockItemInteractionView

final class DockItemInteractionView: NSView, NSDraggingSource {
    /// Pointer travel (in points) before a press becomes a drag instead of a click.
    static let dragThreshold: CGFloat = 4

    var onHover: ((Bool) -> Void)?
    var onClick: (() -> Void)?
    var menuProvider: (() -> NSMenu?)?
    var dragItemProvider: (() -> NSPasteboardWriting?)?
    var dragImage: NSImage?

    private var trackingArea: NSTrackingArea?
    private var mouseDownLocation: NSPoint?
    private var isDragging = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showMenu(for: event)
            return
        }
        mouseDownLocation = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let start = mouseDownLocation else { return }
        let distance = hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y)
        guard distance >= Self.dragThreshold, let pasteboardItem = dragItemProvider?() ?? nil else { return }
        isDragging = true
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: dragImage)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownLocation = nil
            isDragging = false
        }
        guard mouseDownLocation != nil, !isDragging else { return }
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        showMenu(for: event)
    }

    // Suppress AppKit's default contextual menu handling; `showMenu` owns it.
    override func menu(for event: NSEvent) -> NSMenu? { nil }

    private func showMenu(for event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    // MARK: NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
}
