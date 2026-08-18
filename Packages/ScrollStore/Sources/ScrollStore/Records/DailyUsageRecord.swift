import Foundation
import GRDB
import ScrollCore

/// GRDB persistence row for one app's daily high-water usage floor.
public struct DailyUsageRecord: Codable, FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "daily_usage" }

    public var dayKey: String
    public var tokenHash: String
    public var minutes: Int
    public var tzIdentifier: String
    public var source: String
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case dayKey = "day_key"
        case tokenHash = "token_hash"
        case minutes
        case tzIdentifier = "tz_identifier"
        case source
        case updatedAt = "updated_at"
    }

    /// Creates a record from a domain usage record and a source tag.
    public init(domain: UsageRecord, source: String) {
        self.dayKey = domain.dayKey.rawValue
        self.tokenHash = domain.tokenHash
        self.minutes = domain.minutes
        self.tzIdentifier = domain.timeZoneID
        self.source = source
        self.updatedAt = domain.updatedAt
    }

    /// Creates a record from raw column values.
    public init(
        dayKey: DayKey,
        tokenHash: String,
        minutes: Int,
        tzIdentifier: String,
        source: String,
        updatedAt: Date
    ) {
        self.dayKey = dayKey.rawValue
        self.tokenHash = tokenHash
        self.minutes = minutes
        self.tzIdentifier = tzIdentifier
        self.source = source
        self.updatedAt = updatedAt
    }

    /// Converts back to the domain model.
    public func toDomain() -> UsageRecord {
        guard let day = DayKey(rawValue: dayKey) else {
            preconditionFailure("Invalid day_key stored in daily_usage: \(dayKey)")
        }
        return UsageRecord(
            dayKey: day,
            tokenHash: tokenHash,
            minutes: minutes,
            timeZoneID: tzIdentifier,
            updatedAt: updatedAt
        )
    }
}
