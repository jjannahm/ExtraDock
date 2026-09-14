// DockPlistWatcher.swift
import Foundation

/// Calls `onChange` when the system Dock's preferences file changes.
@MainActor
final class DockPlistWatcher {
    var onChange: (() -> Void)?
    private let url: URL
    private var fileSource: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var lastModDate: Date?

    init(url: URL = DockConfigReader.plistURL) {
        self.url = url
    }

    func start() {
        guard pollTimer == nil else { return }
        lastModDate = modificationDate()
        startFileWatcher()
        startPollFallback()
    }

    func stop() {
        fileSource?.cancel()
        fileSource = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func startFileWatcher() {
        fileSource?.cancel()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let event = source.data
                self.fileChanged()
                // cfprefsd saves by replacing the file, which leaves this descriptor
                // pointing at the old one; watch the new file instead.
                if event.contains(.rename) || event.contains(.delete) {
                    self.startFileWatcher()
                }
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileSource = source
    }

    private func startPollFallback() {
        // Poll every 2 seconds as fallback (cfprefsd may not flush to disk immediately)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForChanges() }
        }
    }

    private func checkForChanges() {
        guard let modDate = modificationDate() else { return }
        if let last = lastModDate, modDate > last {
            lastModDate = modDate
            onChange?()
        } else if lastModDate == nil {
            lastModDate = modDate
        }
    }

    private func fileChanged() {
        lastModDate = modificationDate()
        onChange?()
    }

    private func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
