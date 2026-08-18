import Foundation
import GRDB
import ScrollCore

/// GRDB persistence row for a cached daily scroll-distance estimate.
public struct DailyDistanceCacheRecord: Codable, FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "daily_distance_cache" }

    public var dayKey: String
    public var tokenHash: String
    public var feet: Double
    public var velocityTableVersion: Int

    enum CodingKeys: String, CodingKey {
        case dayKey = "day_key"
        case tokenHash = "token_hash"
        case feet
        case velocityTableVersion = "velocity_table_version"
    }

    public init(
        dayKey: DayKey,
        tokenHash: String,
        feet: Double,
        velocityTableVersion: Int
    ) {
        self.dayKey = dayKey.rawValue
        self.tokenHash = tokenHash
        self.feet = feet
        self.velocityTableVersion = velocityTableVersion
    }
}
