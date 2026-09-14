import SwiftUI

// MARK: - PositionSettingsView

struct PositionSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Dock Position") {
                Picker("Edge", selection: $settingsViewModel.dockEdge) {
                    ForEach(DockEdge.allCases, id: \.self) { edge in
                        Text(edge.localizedName).tag(edge)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Offset: \(Int(settingsViewModel.edgeOffset))px") {
                    Slider(
                        value: $settingsViewModel.edgeOffset,
                        in: settingsViewModel.edgeOffsetRange,
                        step: 1
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    PositionSettingsView()
        .environmentObject(SettingsViewModel())
}
