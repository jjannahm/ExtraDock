// MirrorDockSettingsView.swift
import AppKit
import SwiftUI

private struct DisplayEntry: Identifiable {
    let id: String
    let name: String
    let hasSystemDock: Bool
}

struct MirrorDockSettingsView: View {
    @Bindable var settings: AppSettings
    let dockState: MirrorDockState

    @State private var displays: [DisplayEntry] = []
    @State private var externalDisplayConnected = DisplayIdentity.isExternalDisplayConnected

    var body: some View {
        Form {
            Section {
                Toggle("Mirror the system Dock", isOn: $settings.mirrorEnabled)
            } footer: {
                Text("Shows a copy of your Dock — pinned apps, recent apps, and folders — on the displays you choose below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(displays) { display in
                    Toggle(isOn: Binding(
                        get: { settings.isMirrorEnabled(onDisplay: display.id, hasSystemDock: display.hasSystemDock) },
                        set: { settings.setMirrorEnabled($0, onDisplay: display.id) }
                    )) {
                        Text(display.name)
                        if display.hasSystemDock {
                            Text("The system Dock is on this display")
                        }
                    }
                }
            } header: {
                Text("Displays")
            } footer: {
                Text(displays.count < 2
                    ? "Connect another display to mirror your Dock onto it."
                    : "Displays you haven't changed show a mirror unless the system Dock is on them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.mirrorEnabled)

            Section {
                LabeledContent("Size: \(Int((settings.mirrorScale * 100).rounded()))%") {
                    Slider(value: $settings.mirrorScale, in: AppSettings.mirrorScaleRange, step: 0.05)
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("You can also drag the dock's inner edge to resize it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.mirrorEnabled)

            Section {
                Toggle("Automatically hide and show the Mirror Dock", isOn: $settings.mirrorAutoHide)
                Toggle("Only show when an external display is connected", isOn: $settings.mirrorOnlyWithExternalDisplay)
            } header: {
                Text("Behavior")
            } footer: {
                Text(behaviorFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.mirrorEnabled)
        }
        .formStyle(.grouped)
        .onAppear(perform: reloadDisplays)
        .onChange(of: dockState.edge) { reloadDisplays() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            reloadDisplays()
        }
    }

    private var behaviorFooter: String {
        var text = "Like the system Dock: it stays out of sight until you move the pointer to the screen edge."
        if settings.mirrorOnlyWithExternalDisplay && !externalDisplayConnected {
            text += " No external display is connected, so the Mirror Dock is off for now."
        }
        return text
    }

    private func reloadDisplays() {
        let dockDisplay = SystemDockLocator.displayKey(orientation: dockState.edge)
        displays = NSScreen.screens.compactMap { screen in
            guard let key = DisplayIdentity.key(for: screen) else { return nil }
            return DisplayEntry(id: key, name: screen.localizedName, hasSystemDock: key == dockDisplay)
        }
        externalDisplayConnected = DisplayIdentity.isExternalDisplayConnected
    }
}
