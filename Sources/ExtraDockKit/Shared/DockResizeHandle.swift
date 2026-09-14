import AppKit
import SwiftUI

// MARK: - DockResizeHandle

/// Thin strip along a dock's inner edge (the side facing into the screen).
/// Dragging it resizes the dock, like dragging the system Dock's divider.
struct DockResizeHandle: View {
    static let thickness: CGFloat = 5

    let edge: DockEdge
    /// Called when a drag starts; returns the size value to resize from.
    let beginResize: () -> CGFloat
    /// Called while dragging with the starting value and how far the pointer
    /// has moved away from the screen edge.
    let resize: (_ startValue: CGFloat, _ outwardDistance: CGFloat) -> Void

    var body: some View {
        ResizeHandleRepresentable(edge: edge, beginResize: beginResize, resize: resize)
            .frame(
                width: edge.isVertical ? Self.thickness : nil,
                height: edge.isVertical ? nil : Self.thickness
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: innerEdgeAlignment)
            .accessibilityHidden(true)
    }

    private var innerEdgeAlignment: Alignment {
        switch edge {
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

private struct ResizeHandleRepresentable: NSViewRepresentable {
    let edge: DockEdge
    let beginResize: () -> CGFloat
    let resize: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> DockResizeHandleView {
        let view = DockResizeHandleView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DockResizeHandleView, context: Context) {
        view.edge = edge
        view.beginResize = beginResize
        view.resize = resize
    }
}

// MARK: - DockResizeHandleView

final class DockResizeHandleView: NSView {
    var edge: DockEdge = .bottom
    var beginResize: (() -> CGFloat)?
    var resize: ((CGFloat, CGFloat) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var dragStart: (location: NSPoint, value: CGFloat)?

    private var resizeCursor: NSCursor {
        edge.isVertical ? .resizeLeftRight : .resizeUpDown
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: resizeCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        resizeCursor.set()
    }

    override func mouseEntered(with event: NSEvent) {
        resizeCursor.set()
    }

    override func mouseExited(with event: NSEvent) {
        if dragStart == nil {
            NSCursor.arrow.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Screen coordinates: the window moves and resizes under the pointer while dragging.
        dragStart = (NSEvent.mouseLocation, beginResize?() ?? 0)
        (window as? DockPanel)?.beginInteraction()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let distance = DockGeometry.outwardDistance(from: dragStart.location, to: NSEvent.mouseLocation, edge: edge)
        resize?(dragStart.value, distance)
        resizeCursor.set()
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil
        (window as? DockPanel)?.endInteraction()
        if !bounds.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.arrow.set()
        }
    }
}
