import SwiftUI

/// Per-panel geometry, observed by the bar view.
@MainActor
@Observable
final class MirrorDockPresentation {
    var layout: MirrorDockLayout

    init(layout: MirrorDockLayout) {
        self.layout = layout
    }
}

struct MirrorDockBarView: View {
    let dockState: MirrorDockState
    let presentation: MirrorDockPresentation
    let launchService: LaunchService
    let beginResize: () -> CGFloat
    let resize: (CGFloat, CGFloat) -> Void

    var body: some View {
        let layout = presentation.layout
        let grouped = groupedItems()
        let size = layout.tileSize
        let isVertical = layout.edge.isVertical
        let stack = isVertical
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))

        stack {
            ForEach(grouped.pinned) { item in
                itemView(item, layout: layout)
            }

            if !grouped.pinned.isEmpty && (!grouped.recent.isEmpty || !grouped.others.isEmpty) {
                DockSeparatorView(tileSize: size, isVerticalDock: isVertical)
            }

            ForEach(grouped.recent) { item in
                itemView(item, layout: layout)
            }

            if !grouped.recent.isEmpty && !grouped.others.isEmpty {
                DockSeparatorView(tileSize: size, isVerticalDock: isVertical)
            }

            ForEach(grouped.others) { item in
                itemView(item, layout: layout)
            }
        }
        .padding(isVertical ? .vertical : .horizontal, 8)
        .padding(isVertical ? .horizontal : .vertical, 4)
        .frame(width: layout.panelSize.width, height: layout.panelSize.height)
        .background(VisualEffectBackground(cornerRadius: MirrorDockLayout.cornerRadius))
        .overlay {
            DockResizeHandle(edge: layout.edge, beginResize: beginResize, resize: resize)
        }
    }

    private func itemView(_ item: MirrorDockItem, layout: MirrorDockLayout) -> some View {
        MirrorDockItemView(item: item, tileSize: layout.tileSize, edge: layout.edge, launchService: launchService)
    }

    private func groupedItems() -> (pinned: [MirrorDockItem], recent: [MirrorDockItem], others: [MirrorDockItem]) {
        let pinned = dockState.items.filter { $0.section == .pinnedApps }
        let recent = dockState.items.filter { $0.section == .recentApps }
        let others = dockState.items.filter { $0.section == .persistentOthers }
        return (pinned, recent, others)
    }
}
