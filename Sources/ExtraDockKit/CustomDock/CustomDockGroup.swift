import Foundation

// MARK: - CustomDockGroup

struct CustomDockGroup: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var items: [CustomDockItem]
    var isExpanded: Bool

    init(
        id: UUID = UUID(),
        title: String,
        items: [CustomDockItem] = [],
        isExpanded: Bool = false
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.isExpanded = isExpanded
    }

    var sortedItems: [CustomDockItem] {
        items.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - CustomDockConfiguration

struct CustomDockConfiguration: Codable, Sendable {
    var items: [CustomDockItem]
    var groups: [CustomDockGroup]

    init(items: [CustomDockItem] = [], groups: [CustomDockGroup] = []) {
        self.items = items
        self.groups = groups
    }
}
