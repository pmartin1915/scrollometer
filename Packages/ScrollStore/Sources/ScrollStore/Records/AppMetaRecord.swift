import Foundation
import GRDB

/// GRDB persistence row for a single key/value app-meta entry.
public struct AppMetaRecord: Codable, FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "app_meta" }

    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}
