import AppKit
import Foundation

// MARK: - LaunchServiceProtocol

@MainActor
protocol LaunchServiceProtocol {
    func launch(item: DockItem)
    func revealInFinder(item: DockItem)
}

// MARK: - LaunchService

@MainActor
final class LaunchService: LaunchServiceProtocol {
    func launch(item: DockItem) {
        switch item.type {
        case .app:
            guard let fileURL = item.fileURL else { return }
            launchApplication(at: fileURL)
        case .file, .folder:
            guard let fileURL = item.fileURL else { return }
            openFile(at: fileURL)
        case .url:
            guard let webURL = item.webURL else { return }
            NSWorkspace.shared.open(webURL)
        }
    }

    func revealInFinder(item: DockItem) {
        guard item.type != .url, let fileURL = item.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func launchApplication(at url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                print("Failed to launch application at \(url.path): \(error.localizedDescription)")
            }
        }
    }

    private func openFile(at url: URL) {
        NSWorkspace.shared.open(url)
    }
}
