import AppKit
import Foundation

// MARK: - LaunchServiceProtocol

@MainActor
protocol LaunchServiceProtocol {
    func launch(item: CustomDockItem)
    func revealInFinder(item: CustomDockItem)
}

// MARK: - LaunchService

/// Opens dock items the way the system Dock does. Used by both docks.
@MainActor
final class LaunchService: LaunchServiceProtocol {
    func launch(item: CustomDockItem) {
        switch item.type {
        case .app:
            guard let fileURL = item.fileURL else { return }
            openApplication(at: fileURL)
        case .file, .folder:
            guard let fileURL = item.fileURL else { return }
            NSWorkspace.shared.open(fileURL)
        case .url:
            guard let webURL = item.webURL else { return }
            NSWorkspace.shared.open(webURL)
        }
    }

    func revealInFinder(item: CustomDockItem) {
        guard item.type != .url, let fileURL = item.fileURL else { return }
        revealInFinder(path: fileURL.path)
    }

    /// Launches the app, or brings it forward if it is already running. Unlike
    /// `NSRunningApplication.activate()`, this also asks the app to reopen a window
    /// when it has none (e.g. clicking Finder with no Finder windows open).
    func openApplication(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("ExtraDock: failed to open \(url.path): \(error.localizedDescription)")
            }
        }
    }

    func open(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
