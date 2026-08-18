import XCTest
@testable import ScrollCore

/// Deterministic RNG for property tests (SplitMix64).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class AccumulationTests: XCTestCase {
    private let day = DayKey(rawValue: "2026-08-18")!
    private let hashes = ["0123456789abcdef", "fedcba9876543210", "aaaabbbbccccdddd"]

    // MARK: HighWaterAccumulator

    func testIdempotentUnderShuffleAndDuplication() {
        var rng = SplitMix64(seed: 0xC0FFEE)
        // 200 random cumulative events across 3 apps.
        var events: [(String, Int)] = (0..<200).map { _ in
            (hashes.randomElement(using: &rng)!, Int.random(in: 1...480, using: &rng))
        }
        // Duplicate a third of them and shuffle.
        events += events.filter { _ in Bool.random(using: &rng) }
        events.shuffle(using: &rng)

        var expected: [String: Int] = [:]
        for (hash, minutes) in events {
            expected[hash] = max(expected[hash] ?? 0, minutes)
        }

        var accumulator = HighWaterAccumulator(dayKey: day)
        for (hash, minutes) in events {
            accumulator.record(tokenHash: hash, reportedMinutes: minutes)
        }
        XCTAssertEqual(accumulator.minutes, expected)

        // Re-applying the entire stream changes nothing.
        for (hash, minutes) in events {
            accumulator.record(tokenHash: hash, reportedMinutes: minutes)
        }
        XCTAssertEqual(accumulator.minutes, expected)
    }

    func testMissedFiresNeverOvercountAndSelfHeal() {
        var rng = SplitMix64(seed: 0xC0FFEE)
        let full = (1...60).map { ("0123456789abcdef", $0) }
        let surviving = full.filter { _ in Bool.random(using: &rng) }

        var accumulator = HighWaterAccumulator(dayKey: day)
        for (hash, minutes) in surviving {
            accumulator.record(tokenHash: hash, reportedMinutes: minutes)
        }
        let floor = accumulator.minutes["0123456789abcdef"] ?? 0
        let trueMax = surviving.map(\.1).max() ?? 0
        XCTAssertEqual(floor, trueMax)
        XCTAssertLessThanOrEqual(floor, 60)

        // A later surviving higher event restores the correct floor.
        accumulator.record(tokenHash: "0123456789abcdef", reportedMinutes: 60)
        XCTAssertEqual(accumulator.minutes["0123456789abcdef"], 60)
    }

    func testOutcomes() {
        var accumulator = HighWaterAccumulator(dayKey: day)
        XCTAssertEqual(accumulator.record(tokenHash: hashes[0], reportedMinutes: 0), .rejectedZero)
        XCTAssertEqual(accumulator.record(tokenHash: hashes[0], reportedMinutes: -5), .rejectedZero)
        XCTAssertEqual(accumulator.record(tokenHash: hashes[0], reportedMinutes: 10), .applied)
        XCTAssertEqual(accumulator.record(tokenHash: hashes[0], reportedMinutes: 10), .noChange)
        XCTAssertEqual(accumulator.record(tokenHash: hashes[0], reportedMinutes: 7), .noChange)
        XCTAssertEqual(accumulator.record(tokenHash: hashes[0], reportedMinutes: 2000), .clamped)
        XCTAssertEqual(accumulator.minutes[hashes[0]], 1440)
    }

    // MARK: ThresholdLadder

    func testStandardLadderShape() {
        let steps = ThresholdLadder.steps(config: .standard)
        XCTAssertEqual(steps.count, 104)
        XCTAssertEqual(steps, steps.sorted())
        XCTAssertEqual(Set(steps).count, steps.count, "duplicate steps")
        XCTAssertEqual(steps.filter { $0 == 60 }.count, 1)
        XCTAssertEqual(steps.filter { $0 == 180 }.count, 1)
        XCTAssertEqual(steps.filter { $0 == 480 }.count, 1)
        XCTAssertEqual(steps.first, 1)
        XCTAssertEqual(steps.last, 480)
        XCTAssertEqual(ThresholdLadder.eventCount(config: .standard, appCount: 5), 520)
    }

    func testFallbackLadderShape() {
        let steps = ThresholdLadder.steps(config: .fallback)
        XCTAssertEqual(steps.count, 62)
        XCTAssertEqual(steps, steps.sorted())
        XCTAssertEqual(Set(steps).count, steps.count)
        XCTAssertEqual(steps.first, 2)
        XCTAssertEqual(steps.last, 480)
    }

    func testEventNameRoundTripForAllSteps() {
        let hash = "0123456789abcdef"
        for minutes in ThresholdLadder.steps(config: .standard) {
            let name = ThresholdLadder.eventName(tokenHash: hash, minutes: minutes)
            let parsed = ThresholdLadder.parse(eventName: name)
            XCTAssertEqual(parsed?.tokenHash, hash)
            XCTAssertEqual(parsed?.minutes, minutes)
        }
    }

    func testParseRejectsMalformedNames() {
        let bad = [
            "",
            "a::m:5",
            "b:0123456789abcdef:m:1",
            "a:0123456789abcdef:m:",
            "a:0123456789abcdef:m:zero",
            "a:0123456789abcdef:m:0",
            "a:0123456789abcdef:m:-3",
            "a:0123456789abcdef:m:+5",
            "a:0123456789ABCDEF:m:5",
            "a:0123456789abcde:m:5",
            "a:0123456789abcdef0:m:5",
            "a:0123456789abcdef:x:5",
            "a:0123456789abcdef:m:5:extra",
            "a:0123456789abcdxg:m:5",
        ]
        for name in bad {
            XCTAssertNil(ThresholdLadder.parse(eventName: name), "should reject: \(name)")
        }
    }

    // MARK: Reconciler

    func testMergeNeverLowers() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let later = Date(timeIntervalSince1970: 1_000_600)
        let created = Reconciler.merge(existing: nil, incomingMinutes: 30, at: now, dayKey: day, tokenHash: hashes[0], timeZoneID: "America/Chicago")
        XCTAssertEqual(created.minutes, 30)
        XCTAssertEqual(created.updatedAt, now)

        let lowered = Reconciler.merge(existing: created, incomingMinutes: 10, at: later, dayKey: day, tokenHash: hashes[0], timeZoneID: "America/Chicago")
        XCTAssertEqual(lowered.minutes, 30)
        XCTAssertEqual(lowered.updatedAt, now, "updatedAt must not refresh on no-op merge")

        let equal = Reconciler.merge(existing: created, incomingMinutes: 30, at: later, dayKey: day, tokenHash: hashes[0], timeZoneID: "America/Chicago")
        XCTAssertEqual(equal.updatedAt, now)

        let raised = Reconciler.merge(existing: created, incomingMinutes: 45, at: later, dayKey: day, tokenHash: hashes[0], timeZoneID: "America/Chicago")
        XCTAssertEqual(raised.minutes, 45)
        XCTAssertEqual(raised.updatedAt, later)

        let clamped = Reconciler.merge(existing: created, incomingMinutes: 5000, at: later, dayKey: day, tokenHash: hashes[0], timeZoneID: "America/Chicago")
        XCTAssertEqual(clamped.minutes, 1440)
    }

    func testStaleness() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let exactly36h = now.addingTimeInterval(-36 * 3600)
        let over36h = now.addingTimeInterval(-36 * 3600 - 1)

        XCTAssertFalse(Reconciler.isStale(lastFireAt: exactly36h, now: now, hasCompletedOnboarding: true, recentDaysAllZero: true), "exactly 36h is not yet stale")
        XCTAssertTrue(Reconciler.isStale(lastFireAt: over36h, now: now, hasCompletedOnboarding: true, recentDaysAllZero: true))
        XCTAssertTrue(Reconciler.isStale(lastFireAt: nil, now: now, hasCompletedOnboarding: true, recentDaysAllZero: true))
        XCTAssertFalse(Reconciler.isStale(lastFireAt: nil, now: now, hasCompletedOnboarding: false, recentDaysAllZero: true))
        XCTAssertFalse(Reconciler.isStale(lastFireAt: over36h, now: now, hasCompletedOnboarding: true, recentDaysAllZero: false))
    }

    func testSealingAcrossDSTTransition() {
        let iso = ISO8601DateFormatter()
        // 2026-03-08 is the US spring-forward day; midnight 2026-03-09 in
        // America/Chicago is 05:00 UTC (CDT, -5).
        let dstDay = DayKey(rawValue: "2026-03-08")!
        let justBefore = iso.date(from: "2026-03-09T04:59:00Z")!
        let atBoundary = iso.date(from: "2026-03-09T05:00:00Z")!

        XCTAssertFalse(Reconciler.isSealed(dayKey: dstDay, timeZoneID: "America/Chicago", lastIntervalEnd: justBefore))
        XCTAssertTrue(Reconciler.isSealed(dayKey: dstDay, timeZoneID: "America/Chicago", lastIntervalEnd: atBoundary))
        XCTAssertFalse(Reconciler.isSealed(dayKey: dstDay, timeZoneID: "America/Chicago", lastIntervalEnd: nil))

        // Normal day, normal offset (CST, -6): midnight 2026-01-16 Chicago = 06:00 UTC.
        let normalDay = DayKey(rawValue: "2026-01-15")!
        XCTAssertFalse(Reconciler.isSealed(dayKey: normalDay, timeZoneID: "America/Chicago", lastIntervalEnd: iso.date(from: "2026-01-16T05:59:00Z")!))
        XCTAssertTrue(Reconciler.isSealed(dayKey: normalDay, timeZoneID: "America/Chicago", lastIntervalEnd: iso.date(from: "2026-01-16T06:00:00Z")!))

        // Invalid tz treated as UTC.
        XCTAssertTrue(Reconciler.isSealed(dayKey: normalDay, timeZoneID: "Not/AZone", lastIntervalEnd: iso.date(from: "2026-01-16T00:00:00Z")!))
    }
}
