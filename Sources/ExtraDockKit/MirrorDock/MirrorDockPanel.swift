import AppKit
import SwiftUI

/// A copy of the system Dock shown on one display.
@MainActor
final class MirrorDockPanel: DockPanel {
    private let dockState: MirrorDockState
    private let presentation: MirrorDockPresentation

    init(dockState: MirrorDockState, launchService: LaunchService) {
        self.dockState = dockState
        self.presentation = MirrorDockPresentation(layout: MirrorDockLayout(
            edge: dockState.edge,
            itemCount: dockState.items.count,
            separatorCount: dockState.separatorCount,
            baseTileSize: dockState.tileSize,
            scale: 1
        ))
        // Like extradock, the mirror stays out of full-screen Spaces and hides after inactivity.
        super.init(autoHideMode: .afterInactivity, showsOverFullScreenApps: false)
        setRootView(MirrorDockBarView(dockState: dockState, presentation: presentation, launchService: launchService))
    }

    /// Sizes and positions the panel on `screen` for the current Dock contents.
    func layout(on screen: NSScreen, scale: CGFloat) {
        let visibleFrame = screen.visibleFrame
        let edge = dockState.edge
        let layout = MirrorDockLayout(
            edge: edge,
            itemCount: dockState.items.count,
            separatorCount: dockState.separatorCount,
            baseTileSize: dockState.tileSize,
            scale: scale,
            availableLength: DockGeometry.availableLength(along: edge, in: visibleFrame)
        )
        if presentation.layout != layout {
            presentation.layout = layout
        }
        let origin = DockGeometry.origin(edge: edge, size: layout.panelSize, in: visibleFrame)
        place(frame: NSRect(origin: origin, size: layout.panelSize), edge: edge, screenFrame: screen.frame)
    }
}
