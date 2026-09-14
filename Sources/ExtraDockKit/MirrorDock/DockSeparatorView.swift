import SwiftUI

struct DockSeparatorView: View {
    /// Tile size of the dock the separator sits in.
    let tileSize: CGFloat
    /// True for a dock on the left or right edge, where the separator lies horizontally.
    var isVerticalDock = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white.opacity(0.3))
            .frame(
                width: isVerticalDock ? tileSize * 0.6 : 2,
                height: isVerticalDock ? 2 : tileSize * 0.6
            )
            .padding(isVerticalDock ? .vertical : .horizontal, 4)
    }
}
