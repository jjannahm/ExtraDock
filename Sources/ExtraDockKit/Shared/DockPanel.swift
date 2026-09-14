import AppKit
import SwiftUI

// MARK: - AutoHideMode

enum AutoHideMode {
    /// Hide once the pointer has been still for the delay (the Mirror Dock's behavior).
    case afterInactivity
    /// Hide once the pointer has been outside the dock for the delay, like the system Dock.
    case afterPointerLeaves
}

// MARK: - DockPanel

/// Borderless, non-activating floating panel used by both docks. It never takes
/// focus from the app you are working in, joins every Space, and implements
/// auto-hide: hide after a delay, reveal when the pointer reaches the dock's edge.
@MainActor
class DockPanel: NSPanel {
    /// How close (in points) the pointer must get to the edge to reveal a hidden dock.
    static let revealBand: CGFloat = 8

    private(set) var edge: DockEdge = .bottom
    private(set) var screenFrame: CGRect = .zero
    private(set) var isRevealed = true

    private let autoHideMode: AutoHideMode
    private var autoHideEnabled = false
    private var autoHideDelay: TimeInterval = 5
    private var hideTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var trackingArea: NSTrackingArea?

    init(autoHideMode: AutoHideMode, showsOverFullScreenApps: Bool) {
        self.autoHideMode = autoHideMode
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
    /// such as drag and drop). The window is sized explicitly via `place`.
    func setRootView<Content: View>(_ rootView: Content, container: NSView? = nil) {
        let container = container ?? NSView()
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        contentView = container

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        container.addTrackingArea(area)
        trackingArea = area
    }

    // MARK: Placement

    /// Moves the panel to `frame`, remembering which screen edge it is attached to
    /// so auto-hide knows where to reveal it.
    func place(frame newFrame: NSRect, edge: DockEdge, screenFrame: CGRect) {
        self.edge = edge
        self.screenFrame = screenFrame
        if frame != newFrame {
            setFrame(newFrame, display: true)
            invalidateShadow()
        }
        if isRevealed {
            orderFrontRegardless()
        }
    }

    // MARK: Auto-hide

    func setAutoHide(enabled: Bool, delay: TimeInterval) {
        autoHideDelay = delay
        guard enabled != autoHideEnabled else { return }
        autoHideEnabled = enabled
        if enabled {
            startMonitoringPointer()
            restartHideTimer()
        } else {
            stopMonitoringPointer()
            cancelHideTimer()
            reveal(animated: false)
        }
    }

    func reveal(animated: Bool) {
        guard !isRevealed else { return }
        isRevealed = true
        orderFrontRegardless()
        animateAlpha(to: 1, animated: animated)
        if autoHideEnabled {
            // In pointer-leaves mode this hides the dock again if the pointer never moves onto it.
            restartHideTimer()
        }
    }

    private func conceal() {
        guard isRevealed else { return }
        isRevealed = false
        cancelHideTimer()
        animateAlpha(to: 0, animated: true)
    }

    private func animateAlpha(to target: CGFloat, animated: Bool) {
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = shouldAnimate ? 0.2 : 0
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = target
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isRevealed else { return }
                self.orderOut(nil)
            }
        }
    }

    private func startMonitoringPointer() {
        guard globalMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        // Global monitors miss events over this app's own windows (e.g. the other dock).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved() }
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

    private func pointerMoved() {
        guard autoHideEnabled else { return }
        if !isRevealed {
            if DockGeometry.isPoint(NSEvent.mouseLocation, near: edge, of: screenFrame, band: Self.revealBand) {
                reveal(animated: true)
            }
        } else if autoHideMode == .afterInactivity {
            restartHideTimer()
        }
    }

    private func restartHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideTimerFired() }
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func hideTimerFired() {
        hideTimer = nil
        // Never hide out from under the pointer; leaving the dock restarts the timer.
        guard autoHideEnabled, isRevealed, !frame.contains(NSEvent.mouseLocation) else { return }
        conceal()
    }

    override func mouseEntered(with event: NSEvent) {
        guard autoHideEnabled else { return }
        cancelHideTimer()
    }

    override func mouseExited(with event: NSEvent) {
        guard autoHideEnabled, isRevealed else { return }
        restartHideTimer()
    }

    // MARK: Teardown

    override func close() {
        stopMonitoringPointer()
        cancelHideTimer()
        if let trackingArea {
            contentView?.removeTrackingArea(trackingArea)
        }
        trackingArea = nil
        super.close()
    }
}
