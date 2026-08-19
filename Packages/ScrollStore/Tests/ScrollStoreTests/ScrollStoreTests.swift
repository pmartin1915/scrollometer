import XCTest
import GRDB
import ScrollCore
@testable import ScrollStore

final class ScrollStoreTests: XCTestCase {

    // MARK: - Migration

    func testMigrationsCreateTables() throws {
        let database = try AppDatabase.inMemory()

        let tableNames = try database.writer.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
            )
        }

        XCTAssertTrue(tableNames.contains("tracked_app"))
        XCTAssertTrue(tableNames.contains("daily_usage"))
        XCTAssertTrue(tableNames.contains("daily_distance_cache"))
        XCTAssertTrue(tableNames.contains("app_meta"))
    }

    // MARK: - Drain

    func testDrainInsertsMaxSemanticsAndIsIdempotent() throws {
        let database = try AppDatabase.inMemory()
        let queries = StoreQueries(database: database)
        let bridge = SharedDefaultsBridge(database: database)

        let suiteName = "test.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let defaults = UserDefaults(suiteName: suiteName)!

        let hash1 = "aabbccddeeff0011"
        let hash2 = "1122334455667788"

        try queries.upsertTrackedApp(
            TrackedApp(tokenHash: hash1, userLabel: .tiktok, sortOrder: 0),
            tokenData: Data(),
            now: Date()
        )
        try queries.upsertTrackedApp(
            TrackedApp(tokenHash: hash2, userLabel: .instagram, sortOrder: 1),
            tokenData: Data(),
            now: Date()
        )

        seedUsage(defaults: defaults, key: "usage.v1.2024-01-01", minutesByHash: [hash1: 30, hash2: 45])
        seedUsage(defaults: defaults, key: "usage.v1.2024-01-02", minutesByHash: [hash1: 10, hash2: 20])

        let engine = makeEngine()
        let now = Date()
        let day1 = DayKey(rawValue: "2024-01-01")!
        let day2 = DayKey(rawValue: "2024-01-02")!

        let drained = try bridge.drain(
            defaults: defaults,
            engine: engine,
            timeZoneID: "America/Los_Angeles",
            now: now
        )
        XCTAssertEqual(drained.sorted(), [day1, day2].sorted())

        let firstUsage = try database.writer.read { try DailyUsageRecord.fetchAll($0) }
        XCTAssertEqual(firstUsage.count, 4)
        XCTAssertEqual(minutes(for: day1, hash: hash1, in: firstUsage), 30)
        XCTAssertEqual(minutes(for: day1, hash: hash2, in: firstUsage), 45)
        XCTAssertEqual(minutes(for: day2, hash: hash1, in: firstUsage), 10)
        XCTAssertEqual(minutes(for: day2, hash: hash2, in: firstUsage), 20)

        let firstSnapshot = firstUsage.sorted(by: dailyUsageSort)

        // Drain lower values: floors must stay unchanged, including updatedAt.
        seedUsage(defaults: defaults, key: "usage.v1.2024-01-01", minutesByHash: [hash1: 10, hash2: 5])
        seedUsage(defaults: defaults, key: "usage.v1.2024-01-02", minutesByHash: [hash1: 2, hash2: 3])

        _ = try bridge.drain(
            defaults: defaults,
            engine: engine,
            timeZoneID: "America/Los_Angeles",
            now: now.addingTimeInterval(60)
        )

        let lowerUsage = try database.writer.read { try DailyUsageRecord.fetchAll($0) }
        XCTAssertEqual(lowerUsage.count, 4)
        assertEqualState(lowerUsage.sorted(by: dailyUsageSort), firstSnapshot)

        // Idempotence: drain the original snapshot again with a later `now`.
        seedUsage(defaults: defaults, key: "usage.v1.2024-01-01", minutesByHash: [hash1: 30, hash2: 45])
        seedUsage(defaults: defaults, key: "usage.v1.2024-01-02", minutesByHash: [hash1: 10, hash2: 20])

        _ = try bridge.drain(
            defaults: defaults,
            engine: engine,
            timeZoneID: "America/Los_Angeles",
            now: now.addingTimeInterval(120)
        )

        let againUsage = try database.writer.read { try DailyUsageRecord.fetchAll($0) }
        XCTAssertEqual(againUsage.count, 4)
        assertEqualState(againUsage.sorted(by: dailyUsageSort), firstSnapshot)
    }

    // MARK: - Distance cache

    func testDistanceCacheOnlyForTrackedApps() throws {
        let database = try AppDatabase.inMemory()
        let queries = StoreQueries(database: database)
        let bridge = SharedDefaultsBridge(database: database)

        let suiteName = "test.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let defaults = UserDefaults(suiteName: suiteName)!

        let knownHash = "aabbccddeeff0011"
        let unknownHash = "9999999999999999"

        try queries.upsertTrackedApp(
            TrackedApp(tokenHash: knownHash, userLabel: .tiktok, sortOrder: 0),
            tokenData: Data(),
            now: Date()
        )

        seedUsage(
            defaults: defaults,
            key: "usage.v1.2024-03-01",
            minutesByHash: [knownHash: 30, unknownHash: 15]
        )

        let engine = makeEngine()
        _ = try bridge.drain(
            defaults: defaults,
            engine: engine,
            timeZoneID: "UTC",
            now: Date()
        )

        let cache = try database.writer.read { try DailyDistanceCacheRecord.fetchAll($0) }
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.first?.tokenHash, knownHash)

        let expected = engine.distance(
            minutes: 30,
            profileID: AppLabel.tiktok.defaultVelocityProfileID
        )
        let cacheRow = try XCTUnwrap(cache.first)
        XCTAssertEqual(cacheRow.feet, expected.feet, accuracy: 0.001)
        XCTAssertEqual(cacheRow.velocityTableVersion, expected.tableVersion)

        let usage = try database.writer.read { try DailyUsageRecord.fetchAll($0) }
        XCTAssertEqual(usage.count, 2)
        XCTAssertNotNil(usage.first { $0.tokenHash == unknownHash })

        // Label the previously unknown hash and re-drain; a cache row should appear.
        try queries.upsertTrackedApp(
            TrackedApp(tokenHash: unknownHash, userLabel: .otherText, sortOrder: 1),
            tokenData: Data(),
            now: Date()
        )

        _ = try bridge.drain(
            defaults: defaults,
            engine: engine,
            timeZoneID: "UTC",
            now: Date().addingTimeInterval(1)
        )

        let cache2 = try database.writer.read { try DailyDistanceCacheRecord.fetchAll($0) }
        XCTAssertEqual(cache2.count, 2)
        XCTAssertNotNil(cache2.first { $0.tokenHash == unknownHash })
    }

    // MARK: - StoreQueries round trips

    func testStoreQueriesRoundTrip() throws {
        let database = try AppDatabase.inMemory()
        let queries = StoreQueries(database: database)
        let engine = makeEngine()

        let hash1 = "1111111111111111"
        let hash2 = "2222222222222222"

        try queries.upsertTrackedApp(
            TrackedApp(tokenHash: hash1, userLabel: .tiktok, sortOrder: 0),
            tokenData: Data("a".utf8),
            now: Date()
        )
        try queries.upsertTrackedApp(
            TrackedApp(tokenHash: hash2, userLabel: .instagram, sortOrder: 1),
            tokenData: Data("b".utf8),
            now: Date()
        )

        let day1 = DayKey(rawValue: "2024-05-01")!
        let day2 = DayKey(rawValue: "2024-05-02")!

        try database.writer.write { db in
            let specs: [(DayKey, String, Int)] = [
                (day1, hash1, 10),
                (day1, hash2, 20),
                (day2, hash1, 5),
            ]
            for (day, hash, minutes) in specs {
                guard let record = try TrackedAppRecord.fetchOne(db, key: hash) else {
                    XCTFail("Missing tracked app for \(hash)")
                    continue
                }
                let result = engine.distance(
                    minutes: minutes,
                    profileID: record.velocityProfileID
                )
                let cache = DailyDistanceCacheRecord(
                    dayKey: day,
                    tokenHash: hash,
                    feet: result.feet,
                    velocityTableVersion: result.tableVersion
                )
                try cache.save(db)
            }
        }

        let perApp = try queries.perAppFeet(dayKey: day1)
        XCTAssertEqual(perApp.count, 2)

        let todayTotal = try queries.todayTotalFeet(dayKey: day1)
        XCTAssertEqual(todayTotal, perApp.reduce(0) { $0 + $1.feet }, accuracy: 0.001)

        let totals = try queries.dailyTotals(range: day1...day2)
        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals[0].dayKey, day1)
        XCTAssertEqual(totals[1].dayKey, day2)

        try queries.setMeta("foo", "bar")
        XCTAssertEqual(try queries.meta("foo"), "bar")

        try queries.setMeta("foo", "baz")
        XCTAssertEqual(try queries.meta("foo"), "baz")

        XCTAssertNil(try queries.meta("missing"))
    }

    // MARK: - Helpers

    private func makeEngine() -> ConversionEngine {
        let table = VelocityTable(
            schemaVersion: 1,
            version: 42,
            profiles: [
                VelocityProfile(id: "tiktok", screenHeightsPerMinute: 15.0, basis: "test"),
                VelocityProfile(id: "other_text", screenHeightsPerMinute: 8.5, basis: "test"),
            ]
        )
        let screen = DeviceScreen(physicalHeightInches: 5.5, confidence: .measured)
        return ConversionEngine(table: table, screen: screen)
    }

    private func seedUsage(defaults: UserDefaults, key: String, minutesByHash: [String: Int]) {
        defaults.set(minutesByHash, forKey: key)
    }

    private func minutes(for dayKey: DayKey, hash: String, in records: [DailyUsageRecord]) -> Int? {
        records.first { $0.dayKey == dayKey.rawValue && $0.tokenHash == hash }?.minutes
    }

    private var dailyUsageSort: (DailyUsageRecord, DailyUsageRecord) -> Bool {
        { lhs, rhs in
            if lhs.dayKey == rhs.dayKey {
                return lhs.tokenHash < rhs.tokenHash
            }
            return lhs.dayKey < rhs.dayKey
        }
    }

    private func assertEqualState(_ actual: [DailyUsageRecord], _ expected: [DailyUsageRecord], file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.dayKey, e.dayKey, file: file, line: line)
            XCTAssertEqual(a.tokenHash, e.tokenHash, file: file, line: line)
            XCTAssertEqual(a.minutes, e.minutes, file: file, line: line)
            XCTAssertEqual(a.updatedAt, e.updatedAt, file: file, line: line)
        }
    }
}
