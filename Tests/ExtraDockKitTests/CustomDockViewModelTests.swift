import XCTest
@testable import ExtraDockKit

// MARK: - MockPersistenceService

final class MockPersistenceService: PersistenceServiceProtocol, @unchecked Sendable {
    var savedConfiguration: CustomDockConfiguration?
    var loadResult: Result<CustomDockConfiguration, Error> = .success(CustomDockConfiguration())
    var saveCallCount = 0

    func load() throws -> CustomDockConfiguration {
        switch loadResult {
        case .success(let config): return config
        case .failure(let error): throw error
        }
    }

    func save(_ configuration: CustomDockConfiguration) throws {
        savedConfiguration = configuration
        saveCallCount += 1
    }
}

// MARK: - CustomDockViewModelTests

@MainActor
final class CustomDockViewModelTests: XCTestCase {
    private var mockPersistence: MockPersistenceService!
    private var viewModel: CustomDockViewModel!

    override func setUp() {
        super.setUp()
        mockPersistence = MockPersistenceService()
        viewModel = makeViewModel()
    }

    override func tearDown() {
        viewModel = nil
        mockPersistence = nil
        super.tearDown()
    }

    private func makeViewModel() -> CustomDockViewModel {
        CustomDockViewModel(
            persistenceService: mockPersistence,
            runningAppsMonitor: RunningAppsMonitor(),
            launchService: LaunchService(),
            iconResolver: AppIconResolver()
        )
    }

    private var names: [String] {
        viewModel.items.map(\.displayName)
    }

    // MARK: - Initial State

    func testInit_startsWithEmptyItems() {
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testInit_loadsFromPersistence() {
        let items = [CustomDockItem(type: .app, path: "/app", displayName: "App", sortOrder: 0)]
        mockPersistence.loadResult = .success(CustomDockConfiguration(items: items, groups: []))
        XCTAssertEqual(makeViewModel().items.count, 1)
    }

    func testInit_sortsLoadedItemsBySortOrder() {
        let items = [
            CustomDockItem(type: .app, path: "/b", displayName: "B", sortOrder: 1),
            CustomDockItem(type: .app, path: "/a", displayName: "A", sortOrder: 0)
        ]
        mockPersistence.loadResult = .success(CustomDockConfiguration(items: items, groups: []))
        XCTAssertEqual(makeViewModel().items.map(\.displayName), ["A", "B"])
    }

    func testInit_handlesLoadFailureGracefully() {
        struct TestError: Error {}
        mockPersistence.loadResult = .failure(TestError())
        XCTAssertTrue(makeViewModel().items.isEmpty)
    }

    // MARK: - Add Item

    func testAddItem_appendsToItems() {
        viewModel.addItem(CustomDockItem(type: .app, path: "/app", displayName: "App"))
        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testAddItem_savesPersistence() {
        viewModel.addItem(CustomDockItem(type: .app, path: "/app", displayName: "App"))
        XCTAssertEqual(mockPersistence.saveCallCount, 1)
        XCTAssertEqual(mockPersistence.savedConfiguration?.items.count, 1)
    }

    func testAddItem_assignsCorrectSortOrder() {
        viewModel.addItem(CustomDockItem(type: .app, path: "/app1", displayName: "App1"))
        viewModel.addItem(CustomDockItem(type: .app, path: "/app2", displayName: "App2"))
        viewModel.addItem(CustomDockItem(type: .app, path: "/app3", displayName: "App3"))
        XCTAssertEqual(viewModel.items.map(\.sortOrder), [0, 1, 2])
    }

    func testAddItem_notifiesItemsChanged() {
        var notifications = 0
        viewModel.onItemsChanged = { notifications += 1 }
        viewModel.addItem(CustomDockItem(type: .app, path: "/app", displayName: "App"))
        XCTAssertEqual(notifications, 1)
    }

    // MARK: - Remove Item

    func testRemoveItem_removesFromItems() {
        let item = CustomDockItem(type: .app, path: "/app", displayName: "App")
        viewModel.addItem(item)
        viewModel.removeItem(item)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testRemoveItem_reindexesSortOrders() {
        let item2 = CustomDockItem(type: .app, path: "/app2", displayName: "App2")
        viewModel.addItem(CustomDockItem(type: .app, path: "/app1", displayName: "App1"))
        viewModel.addItem(item2)
        viewModel.addItem(CustomDockItem(type: .app, path: "/app3", displayName: "App3"))
        viewModel.removeItem(item2)
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.items.map(\.sortOrder), [0, 1])
    }

    func testRemoveItem_nonExistent_doesNotCrash() {
        viewModel.removeItem(CustomDockItem(type: .app, path: "/nonexistent", displayName: "Ghost"))
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    // MARK: - Rename Item

    func testRenameItem_updatesDisplayName() {
        viewModel.addItem(CustomDockItem(type: .app, path: "/app", displayName: "Old Name"))
        viewModel.renameItem(viewModel.items[0], to: "New Name")
        XCTAssertEqual(viewModel.items[0].displayName, "New Name")
    }

    func testRenameItem_savesPersistence() {
        viewModel.addItem(CustomDockItem(type: .app, path: "/app", displayName: "App"))
        let countBefore = mockPersistence.saveCallCount
        viewModel.renameItem(viewModel.items[0], to: "Renamed")
        XCTAssertEqual(mockPersistence.saveCallCount, countBefore + 1)
    }

    func testRenameItem_trimsAndIgnoresBlankNames() {
        viewModel.addItem(CustomDockItem(type: .app, path: "/app", displayName: "App"))
        viewModel.renameItem(viewModel.items[0], to: "   ")
        XCTAssertEqual(viewModel.items[0].displayName, "App")
        viewModel.renameItem(viewModel.items[0], to: "  Mail  ")
        XCTAssertEqual(viewModel.items[0].displayName, "Mail")
    }

    // MARK: - Move Item

    func testMoveItem_changesOrder() {
        addApps("App1", "App2", "App3")
        viewModel.moveItem(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(names, ["App2", "App3", "App1"])
    }

    func testMoveItemByID_toEnd() {
        addApps("A", "B", "C")
        viewModel.moveItem(id: viewModel.items[0].id, toInsertionIndex: 3)
        XCTAssertEqual(names, ["B", "C", "A"])
        XCTAssertEqual(viewModel.items.map(\.sortOrder), [0, 1, 2])
    }

    func testMoveItemByID_toStart() {
        addApps("A", "B", "C")
        viewModel.moveItem(id: viewModel.items[2].id, toInsertionIndex: 0)
        XCTAssertEqual(names, ["C", "A", "B"])
    }

    func testMoveItemByID_ontoItselfDoesNothing() {
        addApps("A", "B", "C")
        let saves = mockPersistence.saveCallCount
        viewModel.moveItem(id: viewModel.items[1].id, toInsertionIndex: 1)
        viewModel.moveItem(id: viewModel.items[1].id, toInsertionIndex: 2)
        XCTAssertEqual(names, ["A", "B", "C"])
        XCTAssertEqual(mockPersistence.saveCallCount, saves)
    }

    // MARK: - Add Item From URL

    func testAddItemFromURL_detectsAppType() {
        viewModel.addItemFromURL(URL(fileURLWithPath: "/Applications/Safari.app"))
        XCTAssertEqual(viewModel.items.last?.type, .app)
        XCTAssertEqual(viewModel.items.last?.displayName, "Safari")
    }

    func testAddItemFromURL_detectsFileType() {
        viewModel.addItemFromURL(URL(fileURLWithPath: "/Users/test/document.pdf"))
        XCTAssertEqual(viewModel.items.last?.type, .file)
        XCTAssertEqual(viewModel.items.last?.displayName, "document")
    }

    func testAddItemFromURL_detectsFolderType() {
        viewModel.addItemFromURL(FileManager.default.temporaryDirectory)
        XCTAssertEqual(viewModel.items.last?.type, .folder)
    }

    func testAddItems_webLinkBecomesURLItem() {
        let added = viewModel.addItems(from: [URL(string: "https://www.apple.com/mac/")!])
        XCTAssertEqual(added, 1)
        XCTAssertEqual(viewModel.items.last?.type, .url)
        XCTAssertEqual(viewModel.items.last?.displayName, "www.apple.com")
        XCTAssertEqual(viewModel.items.last?.path, "https://www.apple.com/mac/")
    }

    func testAddItems_ignoresUnsupportedSchemes() {
        XCTAssertEqual(viewModel.addItems(from: [URL(string: "mailto:someone@example.com")!]), 0)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testAddItems_skipsPathsAlreadyInDock() {
        let safari = URL(fileURLWithPath: "/Applications/Safari.app")
        viewModel.addItems(from: [safari])
        let added = viewModel.addItems(from: [safari, safari, URL(fileURLWithPath: "/Applications/Mail.app")])
        XCTAssertEqual(added, 1)
        XCTAssertEqual(names, ["Safari", "Mail"])
    }

    func testAddItems_insertsAtIndex() {
        addApps("A", "C")
        viewModel.addItems(from: [URL(fileURLWithPath: "/Applications/B.app")], at: 1)
        XCTAssertEqual(names, ["A", "B", "C"])
        XCTAssertEqual(viewModel.items.map(\.sortOrder), [0, 1, 2])
    }

    // MARK: - Helpers

    private func addApps(_ names: String...) {
        for name in names {
            viewModel.addItem(CustomDockItem(type: .app, path: "/\(name)", displayName: name))
        }
    }
}
