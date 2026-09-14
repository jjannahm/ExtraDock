import XCTest
@testable import Extradock

final class DockItemTests: XCTestCase {
    // MARK: - Initialization

    func testInit_defaultValues() {
        let item = DockItem(type: .app, path: "/Applications/Safari.app", displayName: "Safari")
        XCTAssertEqual(item.type, .app)
        XCTAssertEqual(item.path, "/Applications/Safari.app")
        XCTAssertEqual(item.displayName, "Safari")
        XCTAssertEqual(item.sortOrder, 0)
    }

    func testInit_customSortOrder() {
        let item = DockItem(type: .file, path: "/tmp/file.txt", displayName: "File", sortOrder: 5)
        XCTAssertEqual(item.sortOrder, 5)
    }

    func testInit_uniqueIDs() {
        let item1 = DockItem(type: .app, path: "/app1", displayName: "App1")
        let item2 = DockItem(type: .app, path: "/app2", displayName: "App2")
        XCTAssertNotEqual(item1.id, item2.id)
    }

    // MARK: - URL Properties

    func testFileURL_forAppType() {
        let item = DockItem(type: .app, path: "/Applications/Safari.app", displayName: "Safari")
        XCTAssertNotNil(item.fileURL)
        XCTAssertEqual(item.fileURL?.path, "/Applications/Safari.app")
    }

    func testFileURL_nilForURLType() {
        let item = DockItem(type: .url, path: "https://apple.com", displayName: "Apple")
        XCTAssertNil(item.fileURL)
    }

    func testWebURL_forURLType() {
        let item = DockItem(type: .url, path: "https://apple.com", displayName: "Apple")
        XCTAssertNotNil(item.webURL)
        XCTAssertEqual(item.webURL?.absoluteString, "https://apple.com")
    }

    func testWebURL_nilForAppType() {
        let item = DockItem(type: .app, path: "/Applications/Safari.app", displayName: "Safari")
        XCTAssertNil(item.webURL)
    }

    // MARK: - Codable

    func testEncoding() throws {
        let id = UUID()
        let item = DockItem(
            id: id,
            type: .app,
            path: "/Applications/Safari.app",
            displayName: "Safari",
            sortOrder: 2
        )
        let data = try JSONEncoder().encode(item)
        XCTAssertFalse(data.isEmpty)
    }

    func testDecoding() throws {
        let id = UUID()
        let original = DockItem(
            id: id,
            type: .folder,
            path: "/Users/test/Documents",
            displayName: "Documents",
            sortOrder: 3
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DockItem.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.sortOrder, original.sortOrder)
    }

    func testRoundTrip_allTypes() throws {
        for itemType in DockItemType.allCases {
            let item = DockItem(type: itemType, path: "/test/\(itemType.rawValue)", displayName: "Test")
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(DockItem.self, from: data)
            XCTAssertEqual(decoded.type, itemType)
        }
    }

    // MARK: - Equatable

    func testEquality_sameID() {
        let id = UUID()
        let item1 = DockItem(id: id, type: .app, path: "/app1", displayName: "App1")
        let item2 = DockItem(id: id, type: .app, path: "/app1", displayName: "App1")
        XCTAssertEqual(item1, item2)
    }

    func testEquality_differentID() {
        let item1 = DockItem(type: .app, path: "/app", displayName: "App")
        let item2 = DockItem(type: .app, path: "/app", displayName: "App")
        XCTAssertNotEqual(item1, item2)
    }

    // MARK: - Hashable

    func testHashable_inSet() {
        let id = UUID()
        let item1 = DockItem(id: id, type: .app, path: "/app", displayName: "App")
        let item2 = DockItem(id: id, type: .app, path: "/app", displayName: "App")
        let set: Set<DockItem> = [item1, item2]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - DockItemType

    func testDockItemType_rawValues() {
        XCTAssertEqual(DockItemType.app.rawValue, "app")
        XCTAssertEqual(DockItemType.file.rawValue, "file")
        XCTAssertEqual(DockItemType.url.rawValue, "url")
        XCTAssertEqual(DockItemType.folder.rawValue, "folder")
    }

    func testDockItemType_allCasesCount() {
        XCTAssertEqual(DockItemType.allCases.count, 4)
    }
}
