import AppKit
import SwiftUI

// MARK: - CustomDockSettingsView

struct CustomDockSettingsView: View {
    @Bindable var settings: AppSettings
    let viewModel: CustomDockViewModel
    let addItems: () -> Void

    @State private var displays: [(key: String, name: String)] = CustomDockSettingsView.currentDisplays()

    var body: some View {
        Form {
            Section {
                Toggle("Show the Custom Dock", isOn: $settings.customEnabled)
                LabeledContent("\(viewModel.items.count) item\(viewModel.items.count == 1 ? "" : "s")") {
                    Button("Add Items…", action: addItems)
                }
            } footer: {
                Text("Your own dock. Drag apps, files, folders, or links onto it; drag icons to reorder; right-click to rename or remove.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Position") {
                Picker("Display", selection: $settings.customDisplay) {
                    Text("Main display").tag("")
                    ForEach(displays, id: \.key) { display in
                        Text(display.name).tag(display.key)
                    }
                }

                Picker("Edge", selection: $settings.customEdge) {
                    ForEach(DockEdge.allCases, id: \.self) { edge in
                        Text(edge.localizedName).tag(edge)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Offset from center: \(Int(settings.customOffset))pt") {
                    HStack {
                        Slider(value: $settings.customOffset, in: AppSettings.edgeOffsetRange, step: 1)
                        Button("Reset") { settings.customOffset = 0 }
                            .disabled(settings.customOffset == 0)
                    }
                }
            }

            Section("Icons") {
                LabeledContent("Icon Size: \(Int(settings.customIconSize))px") {
                    Slider(value: $settings.customIconSize, in: AppSettings.iconSizeRange, step: 4)
                }
                LabeledContent("Spacing: \(Int(settings.customIconSpacing))px") {
                    Slider(value: $settings.customIconSpacing, in: AppSettings.iconSpacingRange, step: 1)
                }
                Toggle("Show Labels", isOn: $settings.customShowLabels)
                Toggle("Monochrome Icons", isOn: $settings.customMonochrome)
            }

            Section("Window") {
                LabeledContent("Opacity: \(Int((settings.customOpacity * 100).rounded()))%") {
                    Slider(value: $settings.customOpacity, in: AppSettings.opacityRange)
                }
            }

            Section("Magnification") {
                Toggle("Enable Magnification on Hover", isOn: $settings.customMagnification)
                if settings.customMagnification {
                    LabeledContent("Scale: \(String(format: "%.1f", settings.customMagnificationScale))×") {
                        Slider(
                            value: $settings.customMagnificationScale,
                            in: AppSettings.magnificationScaleRange,
                            step: 0.1
                        )
                    }
                }
            }

            Section("Behavior") {
                Toggle("Automatically hide when the pointer leaves", isOn: $settings.customAutoHide)
                if settings.customAutoHide {
                    LabeledContent("Hide after \(Int(settings.customAutoHideDelay))s") {
                        Slider(value: $settings.customAutoHideDelay, in: AppSettings.autoHideDelayRange, step: 1)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = Self.currentDisplays()
        }
    }

    private static func currentDisplays() -> [(key: String, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let key = DisplayIdentity.key(for: screen) else { return nil }
            return (key: key, name: screen.localizedName)
        }
    }
}
