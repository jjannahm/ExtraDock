import AppKit
import Combine
import Foundation

// MARK: - RunningAppsMonitor

@MainActor
final class RunningAppsMonitor: ObservableObject {
    @Published private(set) var runningBundleIDs: Set<String> = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        updateRunningApps()
        setupObservers()
    }

    func isRunning(bundleID: String) -> Bool {
        runningBundleIDs.contains(bundleID)
    }

    private func updateRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
        runningBundleIDs = Set(apps.compactMap { $0.bundleIdentifier })
    }

    private func setupObservers() {
        NotificationCenter.default
            .publisher(for: NSWorkspace.didLaunchApplicationNotification, object: NSWorkspace.shared)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    let bundleID = app.bundleIdentifier
                else { return }
                self?.runningBundleIDs.insert(bundleID)
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSWorkspace.didTerminateApplicationNotification, object: NSWorkspace.shared)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    let bundleID = app.bundleIdentifier
                else { return }
                self?.runningBundleIDs.remove(bundleID)
            }
            .store(in: &cancellables)
    }
}
