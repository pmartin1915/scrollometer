import Foundation
import GRDB
import ScrollCore

/// Read/write API used by the main app and widgets.
public struct StoreQueries {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// Sum of cached scroll distance for a single day, in feet.
    public func todayTotalFeet(dayKey: DayKey) throws -> Double {
        try database.writer.read { db in
            try Double.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(SUM(feet), 0)
                    FROM daily_distance_cache
                    WHERE day_key = ?
                    """,
                arguments: [dayKey.rawValue]
            ) ?? 0
        }
    }

    /// Per-app cached scroll distance for a single day.
    public func perAppFeet(dayKey: DayKey) throws -> [(tokenHash: String, feet: Double)] {
        try database.writer.read { db in
            let records = try DailyDistanceCacheRecord
                .filter(Column("day_key") == dayKey.rawValue)
                .order(Column("token_hash"))
                .fetchAll(db)

            return records.map { (tokenHash: $0.tokenHash, feet: $0.feet) }
        }
    }

    /// Per-app raw usage minutes for a single day (from `daily_usage`).
    public func perAppMinutes(dayKey: DayKey) throws -> [(tokenHash: String, minutes: Int)] {
        try database.writer.read { db in
            let records = try DailyUsageRecord
                .filter(Column("day_key") == dayKey.rawValue)
                .order(Column("token_hash"))
                .fetchAll(db)

            return records.map { (tokenHash: $0.tokenHash, minutes: $0.minutes) }
        }
    }

    /// Total cached scroll distance per day across a range, ordered by day.
    public func dailyTotals(range: ClosedRange<DayKey>) throws -> [(dayKey: DayKey, feet: Double)] {
        try database.writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT day_key, COALESCE(SUM(feet), 0) AS total_feet
                    FROM daily_distance_cache
                    WHERE day_key BETWEEN ? AND ?
                    GROUP BY day_key
                    ORDER BY day_key
                    """,
                arguments: [range.lowerBound.rawValue, range.upperBound.rawValue]
            )

            return rows.compactMap { row in
                guard let dayKey = DayKey(rawValue: row["day_key"]) else { return nil }
                return (dayKey: dayKey, feet: row["total_feet"])
            }
        }
    }

    /// All tracked apps, ordered by `sort_order`.
    public func trackedApps() throws -> [TrackedApp] {
        try database.writer.read { db in
            let records = try TrackedAppRecord
                .order(Column("sort_order"))
                .fetchAll(db)
            return records.map { $0.toDomain() }
        }
    }

    /// Inserts or updates a tracked app, preserving its original `created_at` if it already exists.
    public func upsertTrackedApp(_ app: TrackedApp, tokenData: Data, now: Date) throws {
        try database.writer.write { db in
            let createdAt = try TrackedAppRecord.fetchOne(db, key: app.tokenHash)?.createdAt ?? now
            let record = TrackedAppRecord(domain: app, tokenData: tokenData, createdAt: createdAt)
            try record.save(db)
        }
    }

    /// Reads a value from `app_meta`, or `nil` if absent.
    public func meta(_ key: String) throws -> String? {
        try database.writer.read { db in
            try AppMetaRecord.fetchOne(db, key: key)?.value
        }
    }

    /// Sets a value in `app_meta`.
    public func setMeta(_ key: String, _ value: String) throws {
        try database.writer.write { db in
            let record = AppMetaRecord(key: key, value: value)
            try record.save(db)
        }
    }
}
