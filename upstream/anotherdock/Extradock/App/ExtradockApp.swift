import SwiftUI

// MARK: - ExtradockApp

@main
struct ExtradockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settingsViewModel)
        }
    }
}
