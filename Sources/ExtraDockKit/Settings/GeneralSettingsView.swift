import AppKit
import SwiftUI

// MARK: - GeneralSettingsView

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Docks") {
                Toggle("Mirror the system Dock on other displays", isOn: $settings.mirrorEnabled)
                Toggle("Show the Custom Dock", isOn: $settings.customEnabled)
            }

            Section("Startup") {
                Toggle("Launch ExtraDock at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: setLaunchAtLogin
                ))
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if LaunchAtLogin.needsApproval {
                    Text("Approve ExtraDock in System Settings › General › Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                // Re-check periodically: permission is granted in System Settings, outside the app.
                TimelineView(.periodic(from: .now, by: 2)) { _ in
                    accessibilityRow(granted: BadgeReader.isAccessibilityGranted)
                }
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Optional. Lets the Mirror Dock show unread badges and the Dock's own right-click menus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func accessibilityRow(granted: Bool) -> some View {
        if granted {
            Label("Accessibility access is on", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            HStack {
                Label("Accessibility access is off", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Allow Access…") {
                    BadgeReader.requestAccessibilityPermission()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                // Installs from install.sh are signed ad hoc, so macOS ties the permission to one build.
                Text("Already switched on in System Settings? Updating ExtraDock makes macOS treat it as a new app. Select ExtraDock in the Accessibility list, remove it with –, then click Allow Access… again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Couldn't change the login item: \(error.localizedDescription)"
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
