import CoreGraphics

/// Size math for the Custom Dock. The SwiftUI view uses it for frames and the
/// controller uses it for the window size and drop positions, so they always agree.
///
/// The panel can be larger than the visible bar: when magnification is on it
/// reserves transparent room so magnified icons aren't clipped.
struct CustomDockLayout: Equatable {
    static let padding: CGFloat = 8
    static let cornerRadius: CGFloat = 14
    static let labelHeight: CGFloat = 14
    static let labelGap: CGFloat = 2
    static let labelExtraWidth: CGFloat = 12
    static let indicatorSize: CGFloat = 5
    static let indicatorGap: CGFloat = 3
    static let minimumIconSize: CGFloat = 16
    static let emptySize = CGSize(width: 240, height: 110)

    let edge: DockEdge
    let itemCount: Int
    /// Icon size after shrinking to fit the screen; never larger than requested.
    let iconSize: CGFloat
    let spacing: CGFloat
    let showLabels: Bool
    /// Hover magnification factor; 1 means off.
    let magnification: CGFloat

    init(
        edge: DockEdge,
        itemCount: Int,
        iconSize requestedIconSize: CGFloat,
        spacing: CGFloat,
        showLabels: Bool,
        magnification: CGFloat,
        availableLength: CGFloat = .greatestFiniteMagnitude
    ) {
        self.edge = edge
        self.itemCount = max(0, itemCount)
        self.spacing = max(0, spacing)
        self.showLabels = showLabels
        self.magnification = max(1, magnification)
        self.iconSize = Self.fittingIconSize(
            requested: requestedIconSize,
            availableLength: availableLength,
            edge: edge,
            itemCount: self.itemCount,
            spacing: self.spacing,
            showLabels: showLabels,
            magnification: self.magnification
        )
    }

    static let placeholder = CustomDockLayout(
        edge: .bottom, itemCount: 0, iconSize: 64, spacing: 8, showLabels: false, magnification: 1
    )

    // MARK: Sizes

    /// Icon plus its optional label.
    var iconBlockSize: CGSize {
        CGSize(
            width: iconSize + (showLabels ? Self.labelExtraWidth : 0),
            height: iconSize + (showLabels ? Self.labelGap + Self.labelHeight : 0)
        )
    }

    /// Icon block plus the running indicator, which sits on the side facing the
    /// screen edge (below the icon on a bottom dock, beside it on a side dock).
    var cellSize: CGSize {
        let block = iconBlockSize
        let indicator = Self.indicatorGap + Self.indicatorSize
        return edge.isVertical
            ? CGSize(width: block.width + indicator, height: block.height)
            : CGSize(width: block.width, height: block.height + indicator)
    }

    /// The visible frosted bar.
    var barSize: CGSize {
        guard itemCount > 0 else { return Self.emptySize }
        let cell = cellSize
        let count = CGFloat(itemCount)
        let cellLength = edge.isVertical ? cell.height : cell.width
        let length = count * cellLength + (count - 1) * spacing + 2 * Self.padding
        let thickness = (edge.isVertical ? cell.width : cell.height) + 2 * Self.padding
        return edge.isVertical
            ? CGSize(width: thickness, height: length)
            : CGSize(width: length, height: thickness)
    }

    /// Room for magnified icons on the side facing away from the screen edge.
    var outwardOverflow: CGFloat {
        itemCount > 0 ? iconSize * (magnification - 1) : 0
    }

    /// Room for magnified icons past both ends of the bar.
    var endOverflow: CGFloat {
        itemCount > 0 ? max(0, iconSize * (magnification - 1) / 2 - Self.padding) : 0
    }

    /// The whole window: bar plus magnification room.
    var panelSize: CGSize {
        let bar = barSize
        return edge.isVertical
            ? CGSize(width: bar.width + outwardOverflow, height: bar.height + 2 * endOverflow)
            : CGSize(width: bar.width + 2 * endOverflow, height: bar.height + outwardOverflow)
    }

    /// Where the bar sits inside the panel, in AppKit coordinates (origin bottom-left).
    var barFrameInPanel: CGRect {
        let bar = barSize
        switch edge {
        case .bottom: return CGRect(x: endOverflow, y: 0, width: bar.width, height: bar.height)
        case .left: return CGRect(x: 0, y: endOverflow, width: bar.width, height: bar.height)
        case .right: return CGRect(x: outwardOverflow, y: endOverflow, width: bar.width, height: bar.height)
        }
    }

    /// Thickness of the bar measured away from the screen edge.
    var barThickness: CGFloat {
        edge.isVertical ? barSize.width : barSize.height
    }

    // MARK: Drops

    private var step: CGFloat {
        (edge.isVertical ? cellSize.height : cellSize.width) + spacing
    }

    /// Insertion index (0...itemCount) for a drop at `point` in panel coordinates.
    /// Items run left to right on a bottom dock and top to bottom on a side dock.
    func insertionIndex(at point: CGPoint) -> Int {
        guard itemCount > 0 else { return 0 }
        let bar = barFrameInPanel
        let along = edge.isVertical
            ? bar.maxY - Self.padding - point.y
            : point.x - bar.minX - Self.padding
        let cellLength = edge.isVertical ? cellSize.height : cellSize.width
        let index = Int(((along - cellLength / 2) / step).rounded(.down)) + 1
        return min(max(index, 0), itemCount)
    }

    /// Distance from the bar's leading end (left, or top on a side dock) to the
    /// middle of the gap where `index` would insert.
    func insertionMarkerOffset(for index: Int) -> CGFloat {
        let clamped = CGFloat(min(max(index, 0), itemCount))
        return max(2, Self.padding + clamped * step - spacing / 2)
    }

    // MARK: Fitting

    private static func fittingIconSize(
        requested: CGFloat,
        availableLength: CGFloat,
        edge: DockEdge,
        itemCount: Int,
        spacing: CGFloat,
        showLabels: Bool,
        magnification: CGFloat
    ) -> CGFloat {
        let requested = max(minimumIconSize, requested)
        guard itemCount > 0 else { return requested }

        func panelLength(_ size: CGFloat) -> CGFloat {
            let layout = CustomDockLayout(
                uncheckedEdge: edge, itemCount: itemCount, iconSize: size,
                spacing: spacing, showLabels: showLabels, magnification: magnification
            )
            return edge.isVertical ? layout.panelSize.height : layout.panelSize.width
        }

        if panelLength(requested) <= availableLength { return requested }
        // Length grows monotonically with icon size, so binary search the largest fit.
        var low = minimumIconSize
        var high = requested
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if panelLength(mid) <= availableLength { low = mid } else { high = mid }
        }
        return low.rounded(.down)
    }

    private init(
        uncheckedEdge edge: DockEdge,
        itemCount: Int,
        iconSize: CGFloat,
        spacing: CGFloat,
        showLabels: Bool,
        magnification: CGFloat
    ) {
        self.edge = edge
        self.itemCount = itemCount
        self.iconSize = iconSize
        self.spacing = spacing
        self.showLabels = showLabels
        self.magnification = magnification
    }
}
