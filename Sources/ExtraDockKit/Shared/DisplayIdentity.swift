import AppKit

/// Identifies displays in a way that survives reconnects, so per-display
/// settings (which monitors mirror the Dock, where the Custom Dock lives)
/// stick to the same physical monitor.
enum DisplayIdentity {
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Stable key for a display: its hardware UUID, falling back to the display ID.
    static func key(for screen: NSScreen) -> String? {
        guard let id = displayID(for: screen) else { return nil }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return String(id)
    }

    static func screen(forKey key: String?) -> NSScreen? {
        guard let key else { return nil }
        return NSScreen.screens.first { self.key(for: $0) == key }
    }

    /// The display that shows the menu bar.
    static var primaryScreen: NSScreen? {
        NSScreen.screens.first
    }
}
