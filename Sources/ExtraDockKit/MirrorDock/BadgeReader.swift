// BadgeReader.swift
import AppKit
import ApplicationServices
import Observation

/// Reads unread-count badges from the system Dock via the Accessibility API.
/// Without Accessibility permission it waits quietly until permission is granted.
@MainActor
final class BadgeReader {
    private(set) var badges: [String: String] = [:]
    private var pollTimer: Timer?
    private var permissionTimer: Timer?
    private var hasPromptedThisLaunch = false
    var onChange: (([String: String]) -> Void)?

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Starts reading badges. With `requestAccess`, shows the system permission
    /// prompt (at most once per launch) if access hasn't been granted yet.
    func start(requestAccess: Bool) {
        if Self.isAccessibilityGranted {
            startPolling()
            return
        }
        if requestAccess && !hasPromptedThisLaunch {
            hasPromptedThisLaunch = true
            Self.requestAccessibilityPermission()
        }
        waitForPermission()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        permissionTimer?.invalidate()
        permissionTimer = nil
        if !badges.isEmpty {
            badges = [:]
            onChange?([:])
        }
    }

    /// Request accessibility permission (shows system prompt if not yet granted)
    static func requestAccessibilityPermission() {
        // kAXTrustedCheckOptionPrompt is a global constant: borrow it, don't consume it.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        // Poll for permission grant (user may grant it in System Settings)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard Self.isAccessibilityGranted else { return }
                timer.invalidate()
                self?.permissionTimer = nil
                self?.startPolling()
            }
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let newBadges = readDockBadges()
        if newBadges != badges {
            badges = newBadges
            onChange?(newBadges)
        }
    }

    /// Read badge labels from the native Dock via Accessibility API
    private func readDockBadges() -> [String: String] {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return [:]
        }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        // Get children of Dock app
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &childrenRef)
        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return [:]
        }

        var badges: [String: String] = [:]

        for child in children {
            // Look for AXList (the dock item list)
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard let role = roleRef as? String, role == kAXListRole else { continue }

            // Get list children (dock items)
            var listChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &listChildrenRef) == .success,
                  let listChildren = listChildrenRef as? [AXUIElement] else { continue }

            for item in listChildren {
                // Get title (app name)
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
                guard let title = titleRef as? String, !title.isEmpty else { continue }

                // Get status label (badge count)
                var statusRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &statusRef)
                if let status = statusRef as? String, !status.isEmpty {
                    badges[title] = status
                }
            }
        }

        return badges
    }
}
