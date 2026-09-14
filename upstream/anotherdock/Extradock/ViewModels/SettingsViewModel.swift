import Combine
import Foundation
import SwiftUI

// MARK: - DockEdge

enum DockEdge: String, CaseIterable, Codable, Sendable {
    case left
    case right
    case bottom

    var localizedName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .bottom: return "Bottom"
        }
    }
}

// MARK: - SettingsViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    // General
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("autoHide") var autoHide: Bool = false
    @AppStorage("showOnActiveSpaceOnly") var showOnActiveSpaceOnly: Bool = false

    // Appearance
    @AppStorage("iconSize") var iconSize: Double = 64
    @AppStorage("opacity") var opacity: Double = 1.0
    @AppStorage("iconSpacing") var iconSpacing: Double = 8
    @AppStorage("showLabels") var showLabels: Bool = false
    @AppStorage("useMonochromeIcons") var useMonochromeIcons: Bool = false

    // Magnification
    @AppStorage("magnificationEnabled") var magnificationEnabled: Bool = false
    @AppStorage("magnificationScale") var magnificationScale: Double = 1.5

    // Position
    @AppStorage("dockEdgeRaw") var dockEdgeRaw: String = DockEdge.bottom.rawValue
    @AppStorage("edgeOffset") var edgeOffset: Double = 0

    var dockEdge: DockEdge {
        get { DockEdge(rawValue: dockEdgeRaw) ?? .bottom }
        set { dockEdgeRaw = newValue.rawValue }
    }

    // MARK: - Value Ranges

    let iconSizeRange: ClosedRange<Double> = 32...128
    let opacityRange: ClosedRange<Double> = 0.1...1.0
    let iconSpacingRange: ClosedRange<Double> = 0...32
    let edgeOffsetRange: ClosedRange<Double> = 0...200
    let magnificationScaleRange: ClosedRange<Double> = 1.0...3.0
}
