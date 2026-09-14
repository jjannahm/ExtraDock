import CoreGraphics

/// Size math for a Mirror Dock panel (from extradock's panel sizing), extended to
/// side docks and to shrinking tiles when the Dock is longer than the screen.
struct MirrorDockLayout: Equatable {
    static let cornerRadius: CGFloat = 16
    static let minimumTileSize: CGFloat = 16

    let edge: DockEdge
    let itemCount: Int
    let separatorCount: Int
    let scale: CGFloat
    /// Tile size after applying scale and shrinking to fit the screen.
    let tileSize: CGFloat

    init(
        edge: DockEdge,
        itemCount: Int,
        separatorCount: Int,
        baseTileSize: CGFloat,
        scale: CGFloat,
        availableLength: CGFloat = .greatestFiniteMagnitude
    ) {
        self.edge = edge
        self.itemCount = max(0, itemCount)
        self.separatorCount = max(0, separatorCount)
        self.scale = scale
        let scaled = max(Self.minimumTileSize, baseTileSize * scale)
        let fixedLength = CGFloat(self.separatorCount) * 12 * scale + 2 * 16 * scale
        if self.itemCount > 0 {
            let fitting = (availableLength - fixedLength) / CGFloat(self.itemCount)
            tileSize = max(Self.minimumTileSize, min(scaled, fitting.rounded(.down)))
        } else {
            tileSize = scaled
        }
    }

    var padding: CGFloat { 16 * scale }
    var separatorLength: CGFloat { 12 * scale }

    /// Length along the screen edge.
    var length: CGFloat {
        CGFloat(itemCount) * tileSize + CGFloat(separatorCount) * separatorLength + padding * 2
    }

    /// Depth away from the screen edge.
    var thickness: CGFloat {
        tileSize + padding
    }

    var panelSize: CGSize {
        edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
    }
}
