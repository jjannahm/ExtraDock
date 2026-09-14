import Foundation
import Observation

extension Notification.Name {
    /// Posted (after the new value is stored) whenever any `AppSettings` value changes.
    static let extraDockSettingsChanged = Notification.Name("extraDockSettingsChanged")
}

// MARK: - AppSettings

/// Every preference for both docks, persisted in UserDefaults.
/// SwiftUI views observe it directly; AppKit controllers listen for
/// `.extraDockSettingsChanged`.
@MainActor
@Observable
public final class AppSettings {
    // MARK: Ranges

    static let mirrorScaleRange: ClosedRange<Double> = 0.5...2.0
    static let iconSizeRange: ClosedRange<Double> = 32...128
    static let iconSpacingRange: ClosedRange<Double> = 0...32
    static let opacityRange: ClosedRange<Double> = 0.1...1.0
    static let edgeOffsetRange: ClosedRange<Double> = -500...500
    static let magnificationScaleRange: ClosedRange<Double> = 1.0...3.0

    // MARK: Mirror Dock

    var mirrorEnabled: Bool { didSet { store(mirrorEnabled, for: Keys.mirrorEnabled) } }
    /// Per-display choices keyed by `DisplayIdentity.key(for:)`. Displays with no
    /// entry mirror the Dock unless they are the display the system Dock is on.
    var mirrorDisplays: [String: Bool] { didSet { store(mirrorDisplays, for: Keys.mirrorDisplays) } }
    var mirrorScale: Double { didSet { store(mirrorScale, for: Keys.mirrorScale) } }
    /// Slide out of sight until the pointer reaches the screen edge, like the system Dock.
    var mirrorAutoHide: Bool { didSet { store(mirrorAutoHide, for: Keys.mirrorAutoHide) } }
    /// Keep the Mirror Dock away unless an external display is connected.
    var mirrorOnlyWithExternalDisplay: Bool {
        didSet { store(mirrorOnlyWithExternalDisplay, for: Keys.mirrorOnlyWithExternalDisplay) }
    }

    // MARK: Custom Dock

    var customEnabled: Bool { didSet { store(customEnabled, for: Keys.customEnabled) } }
    /// Display key for the Custom Dock; empty means the primary display.
    var customDisplay: String { didSet { store(customDisplay, for: Keys.customDisplay) } }
    var customEdge: DockEdge { didSet { store(customEdge.rawValue, for: Keys.customEdge) } }
    var customOffset: Double { didSet { store(customOffset, for: Keys.customOffset) } }
    var customIconSize: Double { didSet { store(customIconSize, for: Keys.customIconSize) } }
    var customIconSpacing: Double { didSet { store(customIconSpacing, for: Keys.customIconSpacing) } }
    var customOpacity: Double { didSet { store(customOpacity, for: Keys.customOpacity) } }
    var customShowLabels: Bool { didSet { store(customShowLabels, for: Keys.customShowLabels) } }
    var customMonochrome: Bool { didSet { store(customMonochrome, for: Keys.customMonochrome) } }
    var customMagnification: Bool { didSet { store(customMagnification, for: Keys.customMagnification) } }
    var customMagnificationScale: Double {
        didSet { store(customMagnificationScale, for: Keys.customMagnificationScale) }
    }
    var customAutoHide: Bool { didSet { store(customAutoHide, for: Keys.customAutoHide) } }
    /// Keep the Custom Dock away unless an external display is connected.
    var customOnlyWithExternalDisplay: Bool {
        didSet { store(customOnlyWithExternalDisplay, for: Keys.customOnlyWithExternalDisplay) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notificationCenter: NotificationCenter

    /// - Parameter systemDockAutoHides: whether the system Dock hides automatically;
    ///   both docks hide the same way until the user chooses otherwise.
    public init(
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        systemDockAutoHides: Bool = false
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter

        mirrorEnabled = defaults.object(forKey: Keys.mirrorEnabled) as? Bool ?? true
        mirrorDisplays = Self.readBoolDictionary(defaults, Keys.mirrorDisplays)
        mirrorScale = Self.read(defaults, Keys.mirrorScale, default: 1.0, in: Self.mirrorScaleRange)
        mirrorAutoHide = defaults.object(forKey: Keys.mirrorAutoHide) as? Bool ?? systemDockAutoHides
        mirrorOnlyWithExternalDisplay = defaults.object(forKey: Keys.mirrorOnlyWithExternalDisplay) as? Bool ?? false

        customEnabled = defaults.object(forKey: Keys.customEnabled) as? Bool ?? true
        customDisplay = defaults.string(forKey: Keys.customDisplay) ?? ""
        customEdge = DockEdge(rawValue: defaults.string(forKey: Keys.customEdge) ?? "") ?? .bottom
        customOffset = Self.read(defaults, Keys.customOffset, default: 0, in: Self.edgeOffsetRange)
        customIconSize = Self.read(defaults, Keys.customIconSize, default: 64, in: Self.iconSizeRange)
        customIconSpacing = Self.read(defaults, Keys.customIconSpacing, default: 8, in: Self.iconSpacingRange)
        customOpacity = Self.read(defaults, Keys.customOpacity, default: 1.0, in: Self.opacityRange)
        customShowLabels = defaults.object(forKey: Keys.customShowLabels) as? Bool ?? false
        customMonochrome = defaults.object(forKey: Keys.customMonochrome) as? Bool ?? false
        customMagnification = defaults.object(forKey: Keys.customMagnification) as? Bool ?? false
        customMagnificationScale = Self.read(
            defaults, Keys.customMagnificationScale, default: 1.5, in: Self.magnificationScaleRange
        )
        customAutoHide = defaults.object(forKey: Keys.customAutoHide) as? Bool ?? systemDockAutoHides
        customOnlyWithExternalDisplay = defaults.object(forKey: Keys.customOnlyWithExternalDisplay) as? Bool ?? false
    }

    // MARK: When each dock is active

    /// Whether the Mirror Dock should run, given the displays connected right now.
    func isMirrorDockActive(externalDisplayConnected: Bool) -> Bool {
        mirrorEnabled && (externalDisplayConnected || !mirrorOnlyWithExternalDisplay)
    }

    /// Whether the Custom Dock should be on screen, given the displays connected right now.
    func isCustomDockActive(externalDisplayConnected: Bool) -> Bool {
        customEnabled && (externalDisplayConnected || !customOnlyWithExternalDisplay)
    }

    // MARK: Resizing by dragging

    /// Custom Dock icon size after dragging its edge `distance` points into the screen.
    static func customIconSize(resizingFrom startSize: Double, by distance: CGFloat) -> Double {
        clamp((startSize + Double(distance)).rounded(), to: iconSizeRange)
    }

    /// Mirror Dock scale after dragging its edge `distance` points into the screen.
    /// The dock's depth is `(tileSize + 16) × scale`, so this keeps the edge under the pointer.
    static func mirrorScale(resizingFrom startScale: Double, by distance: CGFloat, tileSize: CGFloat) -> Double {
        let depthPerScale = Double(max(1, tileSize + 16))
        return clamp(((startScale + Double(distance) / depthPerScale) * 100).rounded() / 100, to: mirrorScaleRange)
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: Per-display mirroring

    func isMirrorEnabled(onDisplay key: String, hasSystemDock: Bool) -> Bool {
        mirrorDisplays[key] ?? !hasSystemDock
    }

    func setMirrorEnabled(_ enabled: Bool, onDisplay key: String) {
        mirrorDisplays[key] = enabled
    }

    // MARK: Persistence

    private func store(_ value: Any, for key: String) {
        defaults.set(value, forKey: key)
        notificationCenter.post(name: .extraDockSettingsChanged, object: self)
    }

    private static func read(
        _ defaults: UserDefaults,
        _ key: String,
        default fallback: Double,
        in range: ClosedRange<Double>
    ) -> Double {
        clamp((defaults.object(forKey: key) as? NSNumber)?.doubleValue ?? fallback, to: range)
    }

    // UserDefaults hands dictionaries back with NSNumber values.
    private static func readBoolDictionary(_ defaults: UserDefaults, _ key: String) -> [String: Bool] {
        guard let raw = defaults.dictionary(forKey: key) else { return [:] }
        return raw.compactMapValues { ($0 as? NSNumber)?.boolValue }
    }

    enum Keys {
        static let mirrorEnabled = "mirror.enabled"
        static let mirrorDisplays = "mirror.displays"
        static let mirrorScale = "mirror.scale"
        static let mirrorAutoHide = "mirror.autoHide"
        static let mirrorOnlyWithExternalDisplay = "mirror.onlyWithExternalDisplay"
        static let customEnabled = "custom.enabled"
        static let customDisplay = "custom.display"
        static let customEdge = "custom.edge"
        static let customOffset = "custom.offset"
        static let customIconSize = "custom.iconSize"
        static let customIconSpacing = "custom.iconSpacing"
        static let customOpacity = "custom.opacity"
        static let customShowLabels = "custom.showLabels"
        static let customMonochrome = "custom.monochrome"
        static let customMagnification = "custom.magnification"
        static let customMagnificationScale = "custom.magnificationScale"
        static let customAutoHide = "custom.autoHide"
        static let customOnlyWithExternalDisplay = "custom.onlyWithExternalDisplay"
    }
}
