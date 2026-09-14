import XCTest
@testable import Extradock

// MARK: - MockPersistenceService

final class MockPersistenceService: PersistenceServiceProtocol, @unchecked Sendable {
    var savedConfiguration: DockConfiguration?
    var loadResult: Result<DockConfiguration, Error> = .success(DockConfiguration())
    var saveCallCount = 0

    func load() throws -> DockConfiguration {
        switch loadResult {
        case .success(let config): return config
        case .failure(let error): throw error
        }
    }

    func save(_ configuration: DockConfiguration) throws {
        savedConfiguration = configuration
        saveCallCount += 1
    }
}

// MARK: - DockViewModelTests

@MainActor
final class DockViewModelTests: XCTestCase {
    private var mockPersistence: MockPersistenceService!
    private var viewModel: DockViewModel!

    override func setUp() {
        super.setUp()
        mockPersistence = MockPersistenceService()
        viewModel = DockViewModel(
            persistenceService: mockPersistence,
            runningAppsMonitor: RunningAppsMonitor(),
            launchService: LaunchService(),
            iconResolver: AppIconResolver()
        )
    }

    override func tearDown() {
        viewModel = nil
        mockPersistence = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInit_startsWithEmptyItems() {
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testInit_loadsFromPersistence() {
        let items = [DockItem(type: .app, path: "/app", displayName: "App", sortOrder: 0)]
        mockPersistence.loadResult = .success(DockConfiguration(items: items, groups: []))
        let vm = DockViewModel(
            persistenceService: mockPersistence,
            runningAppsMonitor: RunningAppsMonitor(),
            launchService: LaunchService(),
            iconResolver: AppIconResolver()
        )
        XCTAssertEqual(vm.items.count, 1)
    }

    func testInit_handlesLoadFailureGracefully() {
        struct TestError: Error {}
        mockPersistence.loadResult = .failure(TestError())
        let vm = DockViewModel(
            persistenceService: mockPersistence,
            runningAppsMonitor: RunningAppsMonitor(),
            launchService: LaunchService(),
            iconResolver: AppIconResolver()
        )
        XCTAssertTrue(vm.items.isEmpty)
    }

    func testInit_isVisibleByDefault() {
        XCTAssertTrue(viewModel.isVisible)
    }

    // MARK: - Add Item

    func testAddItem_appendsToItems() {
        let item = DockItem(type: .app, path: "/app", displayName: "App")
        viewModel.addItem(item)
        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testAddItem_savesPersistence() {
        let item = DockItem(type: .app, path: "/app", displayName: "App")
        viewModel.addItem(item)
        XCTAssertEqual(mockPersistence.saveCallCount, 1)
        XCTAssertEqual(mockPersistence.savedConfiguration?.items.count, 1)
    }

    func testAddItem_assignsCorrectSortOrder() {
        viewModel.addItem(DockItem(type: .app, path: "/app1", displayName: "App1"))
        viewModel.addItem(DockItem(type: .app, path: "/app2", displayName: "App2"))
        viewModel.addItem(DockItem(type: .app, path: "/app3", displayName: "App3"))
        XCTAssertEqual(viewModel.items[0].sortOrder, 0)
        XCTAssertEqual(viewModel.items[1].sortOrder, 1)
        XCTAssertEqual(viewModel.items[2].sortOrder, 2)
    }

    // MARK: - Remove Item

    func testRemoveItem_removesFromItems() {
        let item = DockItem(type: .app, path: "/app", displayName: "App")
        viewModel.addItem(item)
        viewModel.removeItem(item)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testRemoveItem_reindexesSortOrders() {
        let item1 = DockItem(type: .app, path: "/app1", displayName: "App1")
        let item2 = DockItem(type: .app, path: "/app2", displayName: "App2")
        let item3 = DockItem(type: .app, path: "/app3", displayName: "App3")
        viewModel.addItem(item1)
        viewModel.addItem(item2)
        viewModel.addItem(item3)
        viewModel.removeItem(item2)
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.items[0].sortOrder, 0)
        XCTAssertEqual(viewModel.items[1].sortOrder, 1)
    }

    func testRemoveItem_nonExistent_doesNotCrash() {
        let item = DockItem(type: .app, path: "/nonexistent", displayName: "Ghost")
        viewModel.removeItem(item)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    // MARK: - Rename Item

    func testRenameItem_updatesDisplayName() {
        let item = DockItem(type: .app, path: "/app", displayName: "Old Name")
        viewModel.addItem(item)
        viewModel.renameItem(viewModel.items[0], to: "New Name")
        XCTAssertEqual(viewModel.items[0].displayName, "New Name")
    }

    func testRenameItem_savesPersistence() {
        let item = DockItem(type: .app, path: "/app", displayName: "App")
        viewModel.addItem(item)
        let countBefore = mockPersistence.saveCallCount
        viewModel.renameItem(viewModel.items[0], to: "Renamed")
        XCTAssertEqual(mockPersistence.saveCallCount, countBefore + 1)
    }

    // MARK: - Move Item

    func testMoveItem_changesOrder() {
        viewModel.addItem(DockItem(type: .app, path: "/app1", displayName: "App1"))
        viewModel.addItem(DockItem(type: .app, path: "/app2", displayName: "App2"))
        viewModel.addItem(DockItem(type: .app, path: "/app3", displayName: "App3"))
        viewModel.moveItem(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(viewModel.items[0].displayName, "App2")
        XCTAssertEqual(viewModel.items[1].displayName, "App3")
        XCTAssertEqual(viewModel.items[2].displayName, "App1")
    }

    // MARK: - Toggle Visibility

    func testToggleVisibility_togglesIsVisible() {
        XCTAssertTrue(viewModel.isVisible)
        viewModel.toggleVisibility()
        XCTAssertFalse(viewModel.isVisible)
        viewModel.toggleVisibility()
        XCTAssertTrue(viewModel.isVisible)
    }

    // MARK: - Add Item From URL

    func testAddItemFromURL_detectsAppType() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        viewModel.addItemFromURL(url)
        XCTAssertEqual(viewModel.items.last?.type, .app)
        XCTAssertEqual(viewModel.items.last?.displayName, "Safari")
    }

    func testAddItemFromURL_detectsFileType() {
        let url = URL(fileURLWithPath: "/Users/test/document.pdf")
        viewModel.addItemFromURL(url)
        XCTAssertEqual(viewModel.items.last?.type, .file)
        XCTAssertEqual(viewModel.items.last?.displayName, "document")
    }
}
