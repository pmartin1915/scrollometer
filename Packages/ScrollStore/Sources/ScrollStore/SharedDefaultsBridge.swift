import Foundation
import GRDB
import ScrollCore

/// Drains high-water usage snapshots written by the DeviceActivityMonitor
/// extension from App Group `UserDefaults` into the GRDB database.
public struct SharedDefaultsBridge {
    /// Prefix for usage snapshots stored by the extension.
    public static let usageKeyPrefix = "usage.v1."

    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// Parses a `usage.v1.<dayKey>` key into its `DayKey`.
    internal static func parseUsageKey(_ key: String) -> DayKey? {
        guard key.hasPrefix(usageKeyPrefix) else { return nil }
        let rawValue = String(key.dropFirst(usageKeyPrefix.count))
        return DayKey(rawValue: rawValue)
    }

    /// Reads every `usage.v1.<dayKey>` key from `defaults`, MAX-upserts the
    /// values into `daily_usage` via `Reconciler.merge`, recomputes distance
    /// cache rows for tracked apps, and returns the drained `DayKey`s.
    ///
    /// Unknown token hashes are stored in `daily_usage` but get no distance
    /// cache row until they are labeled as tracked apps.
    @discardableResult
    public func drain(
        defaults: UserDefaults,
        engine: ConversionEngine,
        timeZoneID: String,
        now: Date
    ) throws -> [DayKey] {
        let usageKeys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(Self.usageKeyPrefix)
        }

        var drainedDayKeys: [DayKey] = []
        var affectedPairs: [(DayKey, String)] = []

        try database.writer.write { db in
            let trackedApps = try TrackedAppRecord.fetchAll(db)
            let trackedByHash = Dictionary(
                uniqueKeysWithValues: trackedApps.map { ($0.tokenHash, $0) }
            )

            for key in usageKeys {
                guard let dayKey = Self.parseUsageKey(key) else { continue }
                guard let rawDict = defaults.dictionary(forKey: key) else { continue }
                let minutesByHash: [String: Int] = rawDict.compactMapValues { $0 as? Int }
                guard !minutesByHash.isEmpty else { continue }

                drainedDayKeys.append(dayKey)

                for (tokenHash, incomingMinutes) in minutesByHash {
                    let existingRecord = try DailyUsageRecord.fetchOne(
                        db,
                        key: ["day_key": dayKey.rawValue, "token_hash": tokenHash]
                    )

                    let merged = Reconciler.merge(
                        existing: existingRecord?.toDomain(),
                        incomingMinutes: incomingMinutes,
                        at: now,
                        dayKey: dayKey,
                        tokenHash: tokenHash,
                        timeZoneID: timeZoneID
                    )

                    let source = existingRecord?.source ?? "threshold"
                    let usageRecord = DailyUsageRecord(domain: merged, source: source)
                    try usageRecord.save(db)

                    affectedPairs.append((dayKey, tokenHash))
                }
            }

            // Recompute distance cache for affected (day, app) pairs that are tracked.
            for (dayKey, tokenHash) in affectedPairs {
                guard let tracked = trackedByHash[tokenHash] else { continue }
                guard let usage = try DailyUsageRecord.fetchOne(
                    db,
                    key: ["day_key": dayKey.rawValue, "token_hash": tokenHash]
                ) else { continue }

                let result = engine.distance(
                    minutes: usage.minutes,
                    profileID: tracked.velocityProfileID
                )

                let cache = DailyDistanceCacheRecord(
                    dayKey: dayKey,
                    tokenHash: tokenHash,
                    feet: result.feet,
                    velocityTableVersion: result.tableVersion
                )
                try cache.save(db)
            }
        }

        return Array(Set(drainedDayKeys)).sorted()
    }
}
