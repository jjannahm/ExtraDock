import CoreGraphics

// MARK: - DockEdge

/// The screen edge a dock is attached to. The Mirror Dock follows the system
/// Dock's orientation; the Custom Dock uses whatever the user picks.
public enum DockEdge: String, CaseIterable, Codable, Sendable {
    case left
    case right
    case bottom

    var localizedName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .bottom: return "Bottom"
        }
    }

    var isVertical: Bool { self != .bottom }

    /// Maps the `orientation` value stored in com.apple.dock.plist.
    init(dockOrientation: String?) {
        self = DockEdge(rawValue: dockOrientation ?? "") ?? .bottom
    }
}

// MARK: - DockGeometry

enum DockGeometry {
    /// Origin for a panel of `size` attached to `edge` of `visibleFrame`.
    /// `offset` slides the panel along the edge away from centered, `inset`
    /// pushes it away from the edge (used to stack two docks on one edge).
    /// The result is clamped so the panel stays inside `visibleFrame`.
    static func origin(
        edge: DockEdge,
        size: CGSize,
        in visibleFrame: CGRect,
        offset: CGFloat = 0,
        inset: CGFloat = 0
    ) -> CGPoint {
        var point: CGPoint
        switch edge {
        case .bottom:
            point = CGPoint(x: visibleFrame.midX - size.width / 2 + offset, y: visibleFrame.minY + inset)
        case .left:
            point = CGPoint(x: visibleFrame.minX + inset, y: visibleFrame.midY - size.height / 2 + offset)
        case .right:
            point = CGPoint(x: visibleFrame.maxX - size.width - inset, y: visibleFrame.midY - size.height / 2 + offset)
        }
        point.x = clamp(point.x, lower: visibleFrame.minX, upper: visibleFrame.maxX - size.width)
        point.y = clamp(point.y, lower: visibleFrame.minY, upper: visibleFrame.maxY - size.height)
        return point
    }

    /// Whether `point` lies on the screen and within `band` points of `edge`.
    /// Used to reveal an auto-hidden dock when the pointer reaches its edge.
    static func isPoint(_ point: CGPoint, near edge: DockEdge, of screenFrame: CGRect, band: CGFloat) -> Bool {
        let onScreen = point.x >= screenFrame.minX && point.x <= screenFrame.maxX
            && point.y >= screenFrame.minY && point.y <= screenFrame.maxY
        guard onScreen else { return false }
        switch edge {
        case .bottom: return point.y <= screenFrame.minY + band
        case .left: return point.x <= screenFrame.minX + band
        case .right: return point.x >= screenFrame.maxX - band
        }
    }

    /// Length available for dock content along `edge`.
    static func availableLength(along edge: DockEdge, in visibleFrame: CGRect) -> CGFloat {
        edge.isVertical ? visibleFrame.height : visibleFrame.width
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard upper >= lower else { return lower }
        return min(max(value, lower), upper)
    }
}
