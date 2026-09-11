import Foundation

/// JSON file in Application Support. Malformed or unknown state is discarded safely.
public final class FileStateStore: StatePersisting {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public static func applicationSupportStore(
        fileManager: FileManager = .default
    ) throws -> FileStateStore {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("DawnSend", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileStateStore(
            fileURL: directory.appendingPathComponent("schedule-state.json"),
            fileManager: fileManager
        )
    }

    public func load() throws -> PersistedScheduleState? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        do {
            let state = try decoder.decode(PersistedScheduleState.self, from: data)
            guard state.schemaVersion > 0 else {
                try clear()
                return nil
            }
            return state
        } catch {
            try? clear()
            return nil
        }
    }

    public func save(_ state: PersistedScheduleState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    public func clear() throws {
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
}
