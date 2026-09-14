import AppKit
import SwiftUI

struct MirrorDockItemView: View {
    let item: MirrorDockItem
    let tileSize: CGFloat
    let edge: DockEdge
    let launchService: LaunchService

    @State private var isHovered = false
    @State private var bounceOffset: CGFloat = 0
    @State private var isPressed = false

    var body: some View {
        let stack = edge.isVertical
            ? AnyLayout(HStackLayout(spacing: 2))
            : AnyLayout(VStackLayout(spacing: 2))
        stack {
            if edge == .left {
                runningIndicator
            }
            ZStack(alignment: .topTrailing) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: tileSize - 8, height: tileSize - 8)
                    .scaleEffect(isHovered ? 1.15 : (isPressed ? 0.88 : 1.0))
                    .offset(bounceVector)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                    .animation(.spring(response: 0.2, dampingFraction: 0.4), value: bounceOffset)
                    .animation(.easeInOut(duration: 0.08), value: isPressed)

                // Badge count
                if let badge = item.badgeCount {
                    Text(badge)
                        .font(.system(size: max(9, tileSize * 0.2), weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 4, y: -2)
                }
            }
            if edge != .left {
                runningIndicator
            }
        }
        .frame(width: tileSize, height: tileSize)
        .help(item.name)
        .overlay {
            DockItemInteraction(
                onHover: { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                },
                onClick: handleLeftClick,
                menu: menuForRightClick
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { handleLeftClick() }
    }

    // Running indicator dot, on the side facing the screen edge like the system Dock.
    private var runningIndicator: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 4, height: 4)
            .opacity(item.isRunning ? 1 : 0)
    }

    /// Click bounce moves the icon away from the screen edge.
    private var bounceVector: CGSize {
        switch edge {
        case .bottom: return CGSize(width: 0, height: bounceOffset)
        case .left: return CGSize(width: -bounceOffset, height: 0)
        case .right: return CGSize(width: bounceOffset, height: 0)
        }
    }

    private var accessibilityText: String {
        var parts = [item.name]
        if item.isRunning { parts.append("running") }
        if let badge = item.badgeCount { parts.append("\(badge) notifications") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Actions

    private func handleLeftClick() {
        // Press-down effect
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            isPressed = false
        }

        // Bounce animation
        bounceOffset = -8
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            bounceOffset = 0
        }

        // Perform action
        if item.bundleIdentifier != nil {
            launchService.openApplication(at: URL(fileURLWithPath: item.path))
        } else {
            launchService.open(path: item.path)
        }
    }

    private func menuForRightClick() -> NSMenu? {
        guard item.bundleIdentifier != nil else {
            // Folders and files: reveal in Finder, as before.
            launchService.revealInFinder(path: item.path)
            return nil
        }
        // The system Dock's own menu, read through Accessibility when permitted.
        if let nativeMenu = DockMenuProxy.shared.buildMenu(forAppNamed: item.name) {
            return nativeMenu
        }
        let menu = NSMenu()
        let path = item.path
        menu.addItem(ClosureMenuItem("Open") { [launchService] in
            launchService.openApplication(at: URL(fileURLWithPath: path))
        })
        menu.addItem(ClosureMenuItem("Show in Finder") { [launchService] in
            launchService.revealInFinder(path: path)
        })
        if !BadgeReader.isAccessibilityGranted {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem("Allow Accessibility Access for Full Dock Menus…") {
                BadgeReader.requestAccessibilityPermission()
            })
        }
        return menu
    }
}
