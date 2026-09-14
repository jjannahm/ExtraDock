import AppKit
import SwiftUI

// MARK: - CustomDockItemView

struct CustomDockItemView: View {
    let item: CustomDockItem
    let layout: CustomDockLayout
    let viewModel: CustomDockViewModel
    let settings: AppSettings
    let menu: (CustomDockItem) -> NSMenu

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Properties

    private var isRunning: Bool {
        viewModel.isRunning(item)
    }

    private var scale: CGFloat {
        guard isHovered, layout.magnification > 1 else { return 1 }
        return layout.magnification
    }

    /// Magnified icons grow away from the screen edge.
    private var scaleAnchor: UnitPoint {
        switch layout.edge {
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private var animation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.15)
    }

    // MARK: - Body

    var body: some View {
        let icon = viewModel.icon(for: item)
        cellContent(icon: icon)
            .frame(width: layout.cellSize.width, height: layout.cellSize.height)
            .overlay {
                DockItemInteraction(
                    onHover: { hovering in
                        withAnimation(animation) { isHovered = hovering }
                    },
                    onClick: { viewModel.launchItem(item) },
                    menu: { menu(item) },
                    dragItem: {
                        let pasteboardItem = NSPasteboardItem()
                        pasteboardItem.setString(item.id.uuidString, forType: CustomDockDropView.itemIDType)
                        return pasteboardItem
                    },
                    dragImage: icon
                )
            }
            .zIndex(isHovered ? 1 : 0)
            .help(item.displayName)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.displayName), \(item.type.rawValue)\(isRunning ? ", running" : "")")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { viewModel.launchItem(item) }
    }

    @ViewBuilder
    private func cellContent(icon: NSImage) -> some View {
        let indicator = RunningIndicatorView(size: CustomDockLayout.indicatorSize)
            .opacity(isRunning ? 1 : 0)
        switch layout.edge {
        case .bottom:
            VStack(spacing: CustomDockLayout.indicatorGap) {
                iconBlock(icon: icon)
                indicator
            }
        case .left:
            HStack(spacing: CustomDockLayout.indicatorGap) {
                indicator
                iconBlock(icon: icon)
            }
        case .right:
            HStack(spacing: CustomDockLayout.indicatorGap) {
                iconBlock(icon: icon)
                indicator
            }
        }
    }

    private func iconBlock(icon: NSImage) -> some View {
        VStack(spacing: CustomDockLayout.labelGap) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: layout.iconSize, height: layout.iconSize)
                .grayscale(settings.customMonochrome ? 1.0 : 0.0)
                .shadow(color: isHovered ? .black.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                .scaleEffect(scale, anchor: scaleAnchor)

            if layout.showLabels {
                Text(item.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                    .frame(width: layout.iconBlockSize.width, height: CustomDockLayout.labelHeight)
            }
        }
        .frame(width: layout.iconBlockSize.width, height: layout.iconBlockSize.height)
    }
}
