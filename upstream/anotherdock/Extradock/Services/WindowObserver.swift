import AppKit
import Combine
import Foundation

// MARK: - WindowObserver

@MainActor
final class WindowObserver: ObservableObject {
    @Published private(set) var frontmostApplication: NSRunningApplication?
    @Published private(set) var frontmostBundleID: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        frontmostApplication = NSWorkspace.shared.frontmostApplication
        frontmostBundleID = frontmostApplication?.bundleIdentifier
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default
            .publisher(for: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.frontmostApplication = app
                self?.frontmostBundleID = app?.bundleIdentifier
            }
            .store(in: &cancellables)
    }
}
