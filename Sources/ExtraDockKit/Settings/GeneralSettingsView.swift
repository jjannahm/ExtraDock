import SwiftUI

// MARK: - GeneralSettingsView

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settingsViewModel.launchAtLogin)
                Toggle("Auto-hide when inactive", isOn: $settingsViewModel.autoHide)
                Toggle("Show on active space only", isOn: $settingsViewModel.showOnActiveSpaceOnly)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    GeneralSettingsView()
        .environmentObject(SettingsViewModel())
}
