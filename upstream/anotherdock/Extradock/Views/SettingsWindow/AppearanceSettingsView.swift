import SwiftUI

// MARK: - AppearanceSettingsView

struct AppearanceSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Icons") {
                LabeledContent("Icon Size: \(Int(settingsViewModel.iconSize))px") {
                    Slider(
                        value: $settingsViewModel.iconSize,
                        in: settingsViewModel.iconSizeRange,
                        step: 4
                    )
                }
                LabeledContent("Spacing: \(Int(settingsViewModel.iconSpacing))px") {
                    Slider(
                        value: $settingsViewModel.iconSpacing,
                        in: settingsViewModel.iconSpacingRange,
                        step: 1
                    )
                }
                Toggle("Show Labels", isOn: $settingsViewModel.showLabels)
                Toggle("Monochrome Icons", isOn: $settingsViewModel.useMonochromeIcons)
            }

            Section("Window") {
                LabeledContent("Opacity: \(Int(settingsViewModel.opacity * 100))%") {
                    Slider(
                        value: $settingsViewModel.opacity,
                        in: settingsViewModel.opacityRange
                    )
                }
            }

            Section("Magnification") {
                Toggle("Enable Magnification on Hover", isOn: $settingsViewModel.magnificationEnabled)
                if settingsViewModel.magnificationEnabled {
                    LabeledContent("Scale: \(String(format: "%.1f", settingsViewModel.magnificationScale))×") {
                        Slider(
                            value: $settingsViewModel.magnificationScale,
                            in: settingsViewModel.magnificationScaleRange,
                            step: 0.1
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    AppearanceSettingsView()
        .environmentObject(SettingsViewModel())
}
