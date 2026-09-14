import AppKit

/// Content view of the Custom Dock panel. Accepts files, folders and apps from
/// Finder, links from browsers, and icons dragged within the dock to reorder.
final class CustomDockDropView: NSView {
    /// Pasteboard type carrying the UUID of a Custom Dock item being reordered.
    static let itemIDType = NSPasteboard.PasteboardType("com.extradock.custom-dock-item")

    enum Drop {
        case move(itemID: UUID, insertionIndex: Int)
        case add(urls: [URL], insertionIndex: Int)
    }

    var layoutProvider: () -> CustomDockLayout = { .placeholder }
    /// Insertion index to highlight, or nil when nothing droppable is over the dock.
    var onHover: (Int?) -> Void = { _ in }
    var onDrop: (Drop) -> Bool = { _ in false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([Self.itemIDType, .fileURL, .URL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHover(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHover(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHover(nil)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onHover(nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { onHover(nil) }
        guard let drop = Self.drop(
            from: sender.draggingPasteboard,
            insertionIndex: insertionIndex(for: sender)
        ) else { return false }
        return onDrop(drop)
    }

    /// Interprets pasteboard contents as a reorder or as new items.
    static func drop(from pasteboard: NSPasteboard, insertionIndex: Int) -> Drop? {
        if let idString = pasteboard.string(forType: itemIDType), let id = UUID(uuidString: idString) {
            return .move(itemID: id, insertionIndex: insertionIndex)
        }
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        guard !urls.isEmpty else { return nil }
        return .add(urls: urls, insertionIndex: insertionIndex)
    }

    private func updateHover(for info: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = info.draggingPasteboard
        let isReorder = pasteboard.availableType(from: [Self.itemIDType]) != nil
        guard isReorder || pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) else {
            onHover(nil)
            return []
        }
        onHover(insertionIndex(for: info))
        return isReorder ? .move : .copy
    }

    private func insertionIndex(for info: NSDraggingInfo) -> Int {
        layoutProvider().insertionIndex(at: convert(info.draggingLocation, from: nil))
    }
}
