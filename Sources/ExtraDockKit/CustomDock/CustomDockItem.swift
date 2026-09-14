import Foundation

// MARK: - CustomDockItemType

enum CustomDockItemType: String, Codable, CaseIterable, Sendable {
    case app
    case file
    case url
    case folder
}

// MARK: - CustomDockItem

struct CustomDockItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var type: CustomDockItemType
    var path: String
    var displayName: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        type: CustomDockItemType,
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
