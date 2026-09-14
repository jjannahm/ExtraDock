import AppKit
import Foundation

// MARK: - AppIconResolverProtocol

@MainActor
protocol AppIconResolverProtocol {
    func icon(for item: DockItem) -> NSImage
    func clearCache()
}

// MARK: - AppIconResolver

@MainActor
final class AppIconResolver: AppIconResolverProtocol {
    private var cache: [String: NSImage] = [:]

    func icon(for item: DockItem) -> NSImage {
        if let cached = cache[item.path] {
            return cached
        }

        let image: NSImage
        switch item.type {
        case .app, .file, .folder:
            image = NSWorkspace.shared.icon(forFile: item.path)
        case .url:
            image = NSImage(systemSymbolName: "globe", accessibilityDescription: "URL") ?? NSImage()
        }

        cache[item.path] = image
        return image
    }

    func clearCache() {
        cache.removeAll()
    }
}
