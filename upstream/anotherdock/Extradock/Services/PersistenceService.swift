import Foundation

// MARK: - PersistenceServiceProtocol

protocol PersistenceServiceProtocol: Sendable {
    func load() throws -> DockConfiguration
    func save(_ configuration: DockConfiguration) throws
}

// MARK: - PersistenceService

final class PersistenceService: PersistenceServiceProtocol, Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    static let shared = PersistenceService()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
            let appDirectory = appSupport.appendingPathComponent("Extradock")
            try? FileManager.default.createDirectory(
                at: appDirectory,
                withIntermediateDirectories: true
            )
            self.fileURL = appDirectory.appendingPathComponent("dock-configuration.json")
        }

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc
        self.decoder = JSONDecoder()
    }

    func load() throws -> DockConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return DockConfiguration()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(DockConfiguration.self, from: data)
    }

    func save(_ configuration: DockConfiguration) throws {
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }
}
