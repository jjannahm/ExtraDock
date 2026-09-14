import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(settingsViewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView()
                .environmentObject(settingsViewModel)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            PositionSettingsView()
                .environmentObject(settingsViewModel)
                .tabItem {
                    Label("Position", systemImage: "rectangle.3.group")
                }
        }
        .frame(width: 420, height: 360)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
}
