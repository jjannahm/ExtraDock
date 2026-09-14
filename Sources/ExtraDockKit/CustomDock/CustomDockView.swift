import SwiftUI

// MARK: - CustomDockView

/// Root view of the Custom Dock panel: the frosted bar, attached to its screen
/// edge, inside a transparent area that leaves room for magnified icons.
struct CustomDockView: View {
    let viewModel: CustomDockViewModel
    let settings: AppSettings
    let menu: (CustomDockItem) -> NSMenu
    let beginResize: () -> CGFloat
    let resize: (CGFloat, CGFloat) -> Void

    var body: some View {
        let layout = viewModel.layout
        ZStack(alignment: barAlignment(for: layout.edge)) {
            Color.clear
            bar(layout: layout)
        }
        .frame(width: layout.panelSize.width, height: layout.panelSize.height)
        .opacity(settings.customOpacity)
    }

    private func bar(layout: CustomDockLayout) -> some View {
        ZStack {
            VisualEffectBackground(cornerRadius: CustomDockLayout.cornerRadius)

            RoundedRectangle(cornerRadius: CustomDockLayout.cornerRadius)
                .strokeBorder(viewModel.dropIndex != nil ? Color.accentColor : Color.clear, lineWidth: 2)

            if viewModel.items.isEmpty {
                EmptyStateView()
            } else {
                itemStack(layout: layout)
            }
        }
        .frame(width: layout.barSize.width, height: layout.barSize.height)
        .overlay(alignment: .topLeading) {
            if let index = viewModel.dropIndex, !viewModel.items.isEmpty {
                insertionMarker(layout: layout, index: index)
            }
        }
        .overlay {
            if !viewModel.items.isEmpty {
                DockResizeHandle(edge: layout.edge, beginResize: beginResize, resize: resize)
            }
        }
    }

    @ViewBuilder
    private func itemStack(layout: CustomDockLayout) -> some View {
        if layout.edge.isVertical {
            VStack(spacing: layout.spacing) {
                ForEach(viewModel.items) { item in
                    cell(item, layout: layout)
                }
            }
        } else {
            HStack(spacing: layout.spacing) {
                ForEach(viewModel.items) { item in
                    cell(item, layout: layout)
                }
            }
        }
    }

    private func cell(_ item: CustomDockItem, layout: CustomDockLayout) -> some View {
        CustomDockItemView(item: item, layout: layout, viewModel: viewModel, settings: settings, menu: menu)
    }

    /// Thin accent bar in the gap where a dragged item will land.
    private func insertionMarker(layout: CustomDockLayout, index: Int) -> some View {
        let offset = layout.insertionMarkerOffset(for: index)
        let crossLength = (layout.edge.isVertical ? layout.cellSize.width : layout.cellSize.height)
        let width: CGFloat = layout.edge.isVertical ? crossLength : 3
        let height: CGFloat = layout.edge.isVertical ? 3 : crossLength
        return Capsule()
            .fill(Color.accentColor)
            .frame(width: width, height: height)
            .offset(
                x: layout.edge.isVertical ? CustomDockLayout.padding : offset - 1.5,
                y: layout.edge.isVertical ? offset - 1.5 : CustomDockLayout.padding
            )
            .allowsHitTesting(false)
    }

    private func barAlignment(for edge: DockEdge) -> Alignment {
        switch edge {
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }
}
