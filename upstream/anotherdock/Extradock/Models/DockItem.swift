import Foundation

// MARK: - DockItemType

enum DockItemType: String, Codable, CaseIterable, Sendable {
    case app
    case file
    case url
    case folder
}

// MARK: - DockItem

struct DockItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var type: DockItemType
    var path: String
    var displayName: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        type: DockItemType,
        path: String,
        displayName: String,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.type = type
        self.path = path
        self.displayName = displayName
        self.sortOrder = sortOrder
    }

    var fileURL: URL? {
        guard type != .url else { return nil }
        return URL(fileURLWithPath: path)
    }

    var webURL: URL? {
        guard type == .url else { return nil }
        return URL(string: path)
    }

    var bundleIdentifier: String? {
        guard type == .app else { return nil }
        return Bundle(path: path)?.bundleIdentifier
    }
}
