import AppKit

/// Finds the display the system Dock is on, so the Mirror Dock can default to
/// every *other* display. A side Dock lives on the outermost display in its
/// direction (not necessarily the main one), and a bottom Dock moves to
/// whichever display you summon it on.
@MainActor
enum SystemDockLocator {
    /// Display key of the display hosting the system Dock right now.
    static func displayKey(orientation: DockEdge) -> String? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let frames = screens.map(\.frame)
        let index = dockWindowBounds().flatMap { screenIndex(forDockWindow: $0, screenFrames: frames) }
            ?? fallbackScreenIndex(orientation: orientation, screenFrames: frames)
        return index.flatMap { DisplayIdentity.key(for: screens[$0]) }
    }

    /// Bounds (CoreGraphics coordinates, top-left origin) of the Dock's own window.
    /// Window bounds are readable without Screen Recording permission.
    private static func dockWindowBounds() -> CGRect? {
        guard
            let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier,
            let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        for info in windows {
            guard
                (info[kCGWindowOwnerPID as String] as? pid_t) == dockPID,
                (info[kCGWindowLayer as String] as? Int) == dockLevel,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                bounds.width > 1, bounds.height > 1
            else { continue }
            return bounds
        }
        return nil
    }

    /// Index of the screen (AppKit frames; the first is the main display) that
    /// contains most of a window given in CoreGraphics coordinates.
    nonisolated static func screenIndex(forDockWindow cgBounds: CGRect, screenFrames: [CGRect]) -> Int? {
        guard let mainHeight = screenFrames.first?.maxY else { return nil }
        // CoreGraphics measures y down from the top of the main display; AppKit measures up from its bottom.
        let bounds = CGRect(x: cgBounds.minX, y: mainHeight - cgBounds.maxY, width: cgBounds.width, height: cgBounds.height)
        let overlaps = screenFrames.map { frame -> CGFloat in
            let overlap = frame.intersection(bounds)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        guard let best = overlaps.indices.max(by: { overlaps[$0] < overlaps[$1] }), overlaps[best] > 0 else { return nil }
        return best
    }

    /// Where the Dock normally sits when its window can't be found.
    nonisolated static func fallbackScreenIndex(orientation: DockEdge, screenFrames: [CGRect]) -> Int? {
        guard !screenFrames.isEmpty else { return nil }
        switch orientation {
        case .left: return screenFrames.indices.min { screenFrames[$0].minX < screenFrames[$1].minX }
        case .right: return screenFrames.indices.max { screenFrames[$0].maxX < screenFrames[$1].maxX }
        case .bottom: return 0
        }
    }
}
