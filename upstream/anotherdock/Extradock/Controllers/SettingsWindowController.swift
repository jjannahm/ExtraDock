import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(settingsViewModel: SettingsViewModel) {
        let contentView = SettingsView()
            .environmentObject(settingsViewModel)

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 390),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.contentView = hostingView

        super.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
