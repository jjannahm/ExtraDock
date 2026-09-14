import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    let settings: AppSettings
    let mirrorDockState: MirrorDockState
    let customDockViewModel: CustomDockViewModel
    let addCustomDockItems: () -> Void

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            MirrorDockSettingsView(settings: settings, dockState: mirrorDockState)
                .tabItem {
                    Label("Mirror Dock", systemImage: "rectangle.on.rectangle")
                }

            CustomDockSettingsView(
                settings: settings,
                viewModel: customDockViewModel,
                addItems: addCustomDockItems
            )
            .tabItem {
                Label("Custom Dock", systemImage: "dock.rectangle")
            }
        }
        .frame(width: 480, height: 560)
    }
}
