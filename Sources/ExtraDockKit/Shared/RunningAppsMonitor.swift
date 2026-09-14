// RunningAppsMonitor.swift
import AppKit
import Observation

/// Bundle IDs of running apps, shared by both docks. Views that read
/// `runningBundleIDs` update automatically through Observation.
@MainActor
@Observable
final class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    @ObservationIgnored private var observation: NSKeyValueObservation?
    @ObservationIgnored var onChange: ((Set<String>) -> Void)?

    init() {
        refresh()
        observation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    func isRunning(bundleID: String) -> Bool {
        runningBundleIDs.contains(bundleID)
    }

    private func refresh() {
        let ids = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        if ids != runningBundleIDs {
            runningBundleIDs = ids
            onChange?(ids)
        }
    }
}
