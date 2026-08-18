import Foundation
import GRDB

/// A GRDB-backed database for the Scrollometer app group.
public struct AppDatabase {
    /// The database writer used for reads and writes.
    public let writer: any DatabaseWriter

    /// Opens (creating if needed) the database at `url`, running migrations. WAL mode.
    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var configuration = Configuration()
        configuration.journalMode = .wal

        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        try self.init(writer: queue)
    }

    /// In-memory database for tests.
    public static func inMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue()
        return try AppDatabase(writer: queue)
    }

    /// Creates an instance from an existing writer and runs migrations.
    internal init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Migrations.migrator.migrate(writer)
    }
}
