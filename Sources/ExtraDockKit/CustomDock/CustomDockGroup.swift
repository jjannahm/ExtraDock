import Foundation

// MARK: - DockGroup

struct DockGroup: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var items: [DockItem]
    var isExpanded: Bool

    init(
        id: UUID = UUID(),
        title: String,
        items: [DockItem] = [],
        isExpanded: Bool = false
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.isExpanded = isExpanded
    }

    var sortedItems: [DockItem] {
        items.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - DockConfiguration

struct DockConfiguration: Codable, Sendable {
    var items: [DockItem]
    var groups: [DockGroup]

    init(items: [DockItem] = [], groups: [DockGroup] = []) {
        self.items = items
        self.groups = groups
    }
}
