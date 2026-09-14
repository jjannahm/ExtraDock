import XCTest
@testable import ExtraDockKit

final class PersistenceServiceTests: XCTestCase {
    private var tempDirectory: URL!
    private var service: PersistenceService!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        service = PersistenceService(fileURL: tempDirectory.appendingPathComponent("test-config.json"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        service = nil
        super.tearDown()
    }

    // MARK: - Load Tests

    func testLoad_returnsEmptyConfigWhenFileDoesNotExist() throws {
        let config = try service.load()
        XCTAssertTrue(config.items.isEmpty)
        XCTAssertTrue(config.groups.isEmpty)
    }

    func testLoad_afterSave_returnsCorrectData() throws {
        let items = [
            CustomDockItem(type: .app, path: "/Applications/Safari.app", displayName: "Safari", sortOrder: 0),
            CustomDockItem(type: .file, path: "/Users/test/file.txt", displayName: "File", sortOrder: 1)
        ]
        let config = CustomDockConfiguration(items: items, groups: [])

        try service.save(config)
        let loaded = try service.load()

        XCTAssertEqual(loaded.items.count, 2)
        XCTAssertEqual(loaded.items[0].displayName, "Safari")
        XCTAssertEqual(loaded.items[1].displayName, "File")
    }

    // MARK: - Save Tests

    func testSave_createsFileAtCorrectPath() throws {
        let config = CustomDockConfiguration()
        try service.save(config)
        let fileURL = tempDirectory.appendingPathComponent("test-config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSave_persistsAllItemTypes() throws {
        let items: [CustomDockItem] = CustomDockItemType.allCases.map { itemType in
            CustomDockItem(type: itemType, path: "/\(itemType.rawValue)", displayName: itemType.rawValue.capitalized)
        }
        let config = CustomDockConfiguration(items: items, groups: [])
        try service.save(config)

        let loaded = try service.load()
        XCTAssertEqual(loaded.items.count, CustomDockItemType.allCases.count)
    }

    func testSave_persistsGroups() throws {
        let group = CustomDockGroup(
            title: "Work",
            items: [CustomDockItem(type: .app, path: "/app", displayName: "App")],
            isExpanded: true
        )
        let config = CustomDockConfiguration(items: [], groups: [group])
        try service.save(config)

        let loaded = try service.load()
        XCTAssertEqual(loaded.groups.count, 1)
        XCTAssertEqual(loaded.groups[0].title, "Work")
        XCTAssertTrue(loaded.groups[0].isExpanded)
        XCTAssertEqual(loaded.groups[0].items.count, 1)
    }

    func testSave_overwritesPreviousData() throws {
        let config1 = CustomDockConfiguration(
            items: [CustomDockItem(type: .app, path: "/app1", displayName: "App1")],
            groups: []
        )
        try service.save(config1)

        let config2 = CustomDockConfiguration(
            items: [
                CustomDockItem(type: .app, path: "/app2", displayName: "App2"),
                CustomDockItem(type: .app, path: "/app3", displayName: "App3")
            ],
            groups: []
        )
        try service.save(config2)

        let loaded = try service.load()
        XCTAssertEqual(loaded.items.count, 2)
        XCTAssertEqual(loaded.items[0].displayName, "App2")
    }

    // MARK: - UUID Preservation

    func testRoundTrip_preservesItemIDs() throws {
        let id = UUID()
        let item = CustomDockItem(id: id, type: .app, path: "/app", displayName: "App")
        let config = CustomDockConfiguration(items: [item], groups: [])
        try service.save(config)
        let loaded = try service.load()
        XCTAssertEqual(loaded.items[0].id, id)
    }

    func testRoundTrip_preservesSortOrder() throws {
        let items = [
            CustomDockItem(type: .app, path: "/app1", displayName: "App1", sortOrder: 5),
            CustomDockItem(type: .app, path: "/app2", displayName: "App2", sortOrder: 10)
        ]
        let config = CustomDockConfiguration(items: items, groups: [])
        try service.save(config)
        let loaded = try service.load()
        XCTAssertEqual(loaded.items[0].sortOrder, 5)
        XCTAssertEqual(loaded.items[1].sortOrder, 10)
    }
}
