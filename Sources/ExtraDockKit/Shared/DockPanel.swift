import AppKit
import SwiftUI

// MARK: - DockVisibility

enum DockVisibility: Equatable {
    /// Always on screen.
    case pinned
    /// Like the system Dock with hiding turned on: out of sight until the pointer
    /// rests at the screen edge, and gone again shortly after the pointer leaves.
    case autoHide
    /// Out of sight unless something is being dragged to the edge (an empty
    /// Custom Dock waiting for a drop).
    case revealWhileDragging
}

// MARK: - DockPanel

/// Borderless, non-activating floating panel used by both docks. It never takes
/// focus from the app you are working in, joins every Space, and slides in and
/// out of its screen edge when hiding is on.
@MainActor
class DockPanel: NSPanel {
    /// How close (in points) the pointer must get to the edge to reveal a hidden dock.
    static let revealBand: CGFloat = 6
    /// The pointer has to rest at the edge this long, so crossing onto a neighboring
    /// display doesn't pop the dock open.
    static let revealDelay: TimeInterval = 0.2
    static let hideDelay: TimeInterval = 0.5
    static let slideDuration: TimeInterval = 0.25

    private(set) var edge: DockEdge = .bottom
    private(set) var screenFrame: CGRect = .zero
    /// Where the dock sits when shown.
    private(set) var targetFrame: NSRect = .zero
    private(set) var isRevealed = false
    private(set) var visibility: DockVisibility = .pinned

    private var hasBeenPlaced = false
    private var revealTimer: Timer?
    private var hideTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    private var interactionCount = 0

    init(showsOverFullScreenApps: Bool) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .floating
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if showsOverFullScreenApps {
            behavior.insert(.fullScreenAuxiliary)
        }
        collectionBehavior = behavior
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: Content

    /// Hosts a SwiftUI view inside `container` (which may add AppKit behavior
    /// such as drag and drop). The window is sized explicitly via `update`.
    func setRootView<Content: View>(_ rootView: Content, container: NSView? = nil) {
        let container = container ?? NSView()
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        contentView = container
    }

    // MARK: Placement

    /// Positions the dock against `edge` of a screen and applies its visibility.
    func update(frame newFrame: NSRect, edge: DockEdge, screenFrame: CGRect, visibility newVisibility: DockVisibility) {
        let isFirstPlacement = !hasBeenPlaced
        let visibilityChanged = newVisibility != visibility
        hasBeenPlaced = true
        self.edge = edge
        self.screenFrame = screenFrame
        targetFrame = newFrame
        visibility = newVisibility
        updatePointerMonitoring()

        switch visibility {
        case .pinned:
            cancelTimers()
            show(animated: !isFirstPlacement)
        case .autoHide, .revealWhileDragging:
            if isFirstPlacement {
                hide(animated: false)
            } else if isRevealed {
                moveToTargetFrame()
                if visibilityChanged || !shouldStayRevealed() {
                    scheduleHide()
                }
            } else {
                setFrame(DockGeometry.hiddenFrame(for: targetFrame, edge: edge), display: false)
            }
        }
    }

    /// Shows the dock briefly (e.g. right after items are added) so you can see
    /// where it is, then lets it hide again as usual.
    func peek() {
        guard hasBeenPlaced, visibility != .pinned else { return }
        show(animated: true)
        scheduleHide(after: 1.5)
    }

    /// While an interaction (such as resizing) is in progress the dock never hides.
    func beginInteraction() {
        interactionCount += 1
        cancelTimers()
    }

    func endInteraction() {
        interactionCount = max(0, interactionCount - 1)
        if interactionCount == 0, visibility != .pinned, !shouldStayRevealed() {
            scheduleHide()
        }
    }

    // MARK: Showing and hiding

    private func show(animated: Bool) {
        cancelTimers()
        let wasOnScreen = isRevealed && isVisible
        isRevealed = true
        guard !wasOnScreen else {
            moveToTargetFrame()
            return
        }
        let duration = slideDuration(animated: animated)
        if !isVisible {
            setFrame(duration > 0 ? DockGeometry.hiddenFrame(for: targetFrame, edge: edge) : targetFrame, display: false)
            alphaValue = duration > 0 ? 0 : 1
        }
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(self.targetFrame, display: true)
            self.animator().alphaValue = 1
        }
    }

    private func hide(animated: Bool) {
        cancelTimers()
        isRevealed = false
        let hiddenFrame = DockGeometry.hiddenFrame(for: targetFrame, edge: edge)
        let duration = slideDuration(animated: animated)
        guard isVisible, duration > 0 else {
            orderOut(nil)
            alphaValue = 0
            setFrame(hiddenFrame, display: false)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(hiddenFrame, display: true)
            self.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isRevealed else { return }
                self.orderOut(nil)
            }
        }
    }

    private func moveToTargetFrame() {
        guard frame != targetFrame else { return }
        setFrame(targetFrame, display: true)
        invalidateShadow()
    }

    private func slideDuration(animated: Bool) -> TimeInterval {
        animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? Self.slideDuration : 0
    }

    // MARK: Pointer tracking

    private func updatePointerMonitoring() {
        if visibility == .pinned {
            stopMonitoringPointer()
        } else {
            startMonitoringPointer()
        }
    }

    private func startMonitoringPointer() {
        guard globalMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.pointerEvent(type) }
        }
        // Global monitors miss events over this app's own windows (e.g. the other dock).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.pointerEvent(type) }
            return event
        }
    }

    private func stopMonitoringPointer() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func pointerEvent(_ type: NSEvent.EventType) {
        if type == .leftMouseDown {
            dragChangeCountAtMouseDown = NSPasteboard(name: .drag).changeCount
        }
        guard visibility != .pinned, interactionCount == 0 else { return }

        if !isRevealed {
            if isPointerInRevealZone && isRevealAllowed {
                scheduleReveal()
            } else {
                cancelReveal()
            }
        } else if shouldStayRevealed() {
            cancelHide()
        } else if hideTimer == nil {
            scheduleHide()
        }
    }

    /// True while files, links, or text are being dragged (not windows or selections).
    private var isContentDragInProgress: Bool {
        NSEvent.pressedMouseButtons & 1 == 1
            && NSPasteboard(name: .drag).changeCount != dragChangeCountAtMouseDown
    }

    private var isRevealAllowed: Bool {
        visibility == .autoHide || isContentDragInProgress
    }

    private var isPointerInRevealZone: Bool {
        DockGeometry.isPoint(NSEvent.mouseLocation, near: edge, of: screenFrame, band: Self.revealBand)
    }

    private func shouldStayRevealed() -> Bool {
        if interactionCount > 0 { return true }
        let pointerOverDock = targetFrame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) || isPointerInRevealZone
        switch visibility {
        case .pinned: return true
        case .autoHide: return pointerOverDock
        case .revealWhileDragging: return pointerOverDock && isContentDragInProgress
        }
    }

    private func scheduleReveal() {
        guard revealTimer == nil else { return }
        revealTimer = Timer.scheduledTimer(withTimeInterval: Self.revealDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.revealTimer = nil
                guard !self.isRevealed, self.visibility != .pinned,
                      self.isPointerInRevealZone, self.isRevealAllowed else { return }
                self.show(animated: true)
            }
        }
    }

    private func scheduleHide(after delay: TimeInterval? = nil) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay ?? Self.hideDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hideTimer = nil
                guard self.isRevealed, self.visibility != .pinned, !self.shouldStayRevealed() else { return }
                self.hide(animated: true)
            }
        }
    }

    private func cancelReveal() {
        revealTimer?.invalidate()
        revealTimer = nil
    }

    private func cancelHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func cancelTimers() {
        cancelReveal()
        cancelHide()
    }

    // MARK: Teardown

    override func close() {
        stopMonitoringPointer()
        cancelTimers()
        super.close()
    }
}
