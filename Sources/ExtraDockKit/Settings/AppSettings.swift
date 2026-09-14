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
    static let autoHideDelayRange: ClosedRange<Double> = 1...30
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
    var mirrorAutoHide: Bool { didSet { store(mirrorAutoHide, for: Keys.mirrorAutoHide) } }
    var mirrorAutoHideDelay: Double { didSet { store(mirrorAutoHideDelay, for: Keys.mirrorAutoHideDelay) } }

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
    var customAutoHideDelay: Double { didSet { store(customAutoHideDelay, for: Keys.customAutoHideDelay) } }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notificationCenter: NotificationCenter

    public init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter

        mirrorEnabled = defaults.object(forKey: Keys.mirrorEnabled) as? Bool ?? true
        mirrorDisplays = Self.readBoolDictionary(defaults, Keys.mirrorDisplays)
        mirrorScale = Self.read(defaults, Keys.mirrorScale, default: 1.0, in: Self.mirrorScaleRange)
        mirrorAutoHide = defaults.object(forKey: Keys.mirrorAutoHide) as? Bool ?? false
        mirrorAutoHideDelay = Self.read(defaults, Keys.mirrorAutoHideDelay, default: 5, in: Self.autoHideDelayRange)

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
        customAutoHide = defaults.object(forKey: Keys.customAutoHide) as? Bool ?? false
        customAutoHideDelay = Self.read(defaults, Keys.customAutoHideDelay, default: 1, in: Self.autoHideDelayRange)
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
        let value = (defaults.object(forKey: key) as? NSNumber)?.doubleValue ?? fallback
        return min(max(value, range.lowerBound), range.upperBound)
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
        static let mirrorAutoHideDelay = "mirror.autoHideDelay"
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
        static let customAutoHideDelay = "custom.autoHideDelay"
    }
}
