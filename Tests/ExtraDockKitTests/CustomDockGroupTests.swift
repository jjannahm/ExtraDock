import XCTest
@testable import ExtraDockKit

final class CustomDockGroupTests: XCTestCase {
    // MARK: - Initialization

    func testInit_defaultValues() {
        let group = CustomDockGroup(title: "Test Group")
        XCTAssertEqual(group.title, "Test Group")
        XCTAssertTrue(group.items.isEmpty)
        XCTAssertFalse(group.isExpanded)
    }

    func testInit_withItems() {
        let items = [
            CustomDockItem(type: .app, path: "/app1", displayName: "App1", sortOrder: 1),
            CustomDockItem(type: .app, path: "/app2", displayName: "App2", sortOrder: 0)
        ]
        let group = CustomDockGroup(title: "Apps", items: items, isExpanded: true)
        XCTAssertEqual(group.items.count, 2)
        XCTAssertTrue(group.isExpanded)
    }

    // MARK: - Sorted Items

    func testSortedItems_returnsItemsInOrder() {
        let items = [
            CustomDockItem(type: .app, path: "/app1", displayName: "App1", sortOrder: 2),
            CustomDockItem(type: .app, path: "/app2", displayName: "App2", sortOrder: 0),
            CustomDockItem(type: .app, path: "/app3", displayName: "App3", sortOrder: 1)
        ]
        let group = CustomDockGroup(title: "Test", items: items)
        let sorted = group.sortedItems
        XCTAssertEqual(sorted[0].displayName, "App2")
        XCTAssertEqual(sorted[1].displayName, "App3")
        XCTAssertEqual(sorted[2].displayName, "App1")
    }

    func testSortedItems_emptyGroup() {
        let group = CustomDockGroup(title: "Empty")
        XCTAssertTrue(group.sortedItems.isEmpty)
    }

    // MARK: - Codable

    func testEncoding() throws {
        let group = CustomDockGroup(title: "Test Group", isExpanded: true)
        let data = try JSONEncoder().encode(group)
        XCTAssertFalse(data.isEmpty)
    }

    func testDecoding() throws {
        let id = UUID()
        let items = [CustomDockItem(type: .app, path: "/app", displayName: "App")]
        let original = CustomDockGroup(id: id, title: "My Group", items: items, isExpanded: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomDockGroup.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.items.count, original.items.count)
        XCTAssertEqual(decoded.isExpanded, original.isExpanded)
    }

    // MARK: - Equatable

    func testEquality_sameID() {
        let id = UUID()
        let group1 = CustomDockGroup(id: id, title: "Group")
        let group2 = CustomDockGroup(id: id, title: "Group")
        XCTAssertEqual(group1, group2)
    }

    func testEquality_differentID() {
        let group1 = CustomDockGroup(title: "Group")
        let group2 = CustomDockGroup(title: "Group")
        XCTAssertNotEqual(group1, group2)
    }
}

// MARK: - CustomDockConfigurationTests

final class CustomDockConfigurationTests: XCTestCase {
    func testInit_defaultValues() {
        let config = CustomDockConfiguration()
        XCTAssertTrue(config.items.isEmpty)
        XCTAssertTrue(config.groups.isEmpty)
    }

    func testInit_withContent() {
        let items = [CustomDockItem(type: .app, path: "/app", displayName: "App")]
        let groups = [CustomDockGroup(title: "Group")]
        let config = CustomDockConfiguration(items: items, groups: groups)
        XCTAssertEqual(config.items.count, 1)
        XCTAssertEqual(config.groups.count, 1)
    }

    func testRoundTrip_codable() throws {
        let items = [
            CustomDockItem(type: .app, path: "/Applications/Safari.app", displayName: "Safari"),
            CustomDockItem(type: .url, path: "https://apple.com", displayName: "Apple")
        ]
        let groups = [CustomDockGroup(title: "Productivity")]
        let config = CustomDockConfiguration(items: items, groups: groups)

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CustomDockConfiguration.self, from: data)

        XCTAssertEqual(decoded.items.count, config.items.count)
        XCTAssertEqual(decoded.groups.count, config.groups.count)
        XCTAssertEqual(decoded.items[0].displayName, "Safari")
        XCTAssertEqual(decoded.items[1].path, "https://apple.com")
    }
}
