# WP3 — ScrollCore: threshold accumulation + ladder + reconciliation

## Goal
The noisy-data defense layer, pure Foundation, exhaustively unit-tested. The Screen Time pipeline delivers cumulative threshold events ("app X has used ≥ N minutes today") that may arrive duplicated, out of order, or not at all. This package makes that signal safe.

## Types (Sources/ScrollCore/Accumulation/)

```swift
public struct HighWaterAccumulator: Sendable {
    // State: [String tokenHash: Int minutes] for ONE DayKey.
    public private(set) var dayKey: DayKey
    public private(set) var minutes: [String: Int]
    public init(dayKey: DayKey, existing: [String: Int] = [:])
    /// Idempotent: record(tokenHash:, reportedMinutes:) sets minutes[hash] = max(current, reported).
    /// reportedMinutes <= 0 is IGNORED and returned as .rejectedZero (iOS 26.2 zero-minutes bug defense).
    /// reportedMinutes > 1440 clamps to 1440, returned as .clamped.
    @discardableResult public mutating func record(tokenHash: String, reportedMinutes: Int) -> RecordOutcome
}
public enum RecordOutcome: Equatable { case applied, noChange, rejectedZero, clamped }

public struct LadderConfig: Codable, Equatable, Sendable {
    public var fineStepMinutes: Int      // default 1
    public var fineUpTo: Int             // default 60
    public var mediumStepMinutes: Int    // default 5
    public var mediumUpTo: Int           // default 180
    public var coarseStepMinutes: Int    // default 15
    public var coarseUpTo: Int           // default 480
    public static let standard: LadderConfig
    public static let fallback: LadderConfig  // fine 2-min steps → ~62 events/app
}

public enum ThresholdLadder {
    /// steps(config:) -> [Int]  e.g. [1,2,...,60,65,...,180,195,...,480]; strictly ascending, no duplicates.
    /// eventName(tokenHash8:minutes:) -> String  "a:<hash8>:m:<minutes>"
    /// parse(eventName:) -> (tokenHash8: String, minutes: Int)?   // strict; malformed → nil
    /// eventCount(config:appCount:) -> Int
}

public struct Reconciler: Sendable {
    /// merge(existing: UsageRecord?, incomingMinutes: Int, at: Date) -> UsageRecord
    ///   MAX semantics; never lowers minutes; refreshes updatedAt only on change.
    /// isStale(lastFireAt: Date?, now: Date, hasCompletedOnboarding: Bool, recentDaysAllZero: Bool) -> Bool
    ///   true iff onboarded AND lastFireAt older than 36h (or nil) AND recentDaysAllZero.
    /// seal semantics: a DayKey is sealed when `lastIntervalEnd` >= end-of-day for that key in its tz;
    ///   isSealed(dayKey:timeZoneID:lastIntervalEnd:) -> Bool
}
```

## Tests (Tests/ScrollCoreTests/)

1. **Idempotence**: applying any sequence of (hash, minutes) events, in any order, with arbitrary duplication, yields the same state as applying only the per-hash maxima. Include a shuffled/duplicated property test (seeded RNG, deterministic).
2. **Missed-fire self-healing**: dropping any subset of events never yields a total above the true value, and a later surviving higher event restores the correct floor.
3. Zero/negative reported minutes rejected; 1441+ clamps.
4. **Ladder generation**: standard config produces exactly 104 steps (60 + 24 + 20); fallback ~62; strictly ascending; boundary values (60, 180, 480) each appear exactly once; `eventCount(standard, appCount: 5) == 520`.
5. **Event-name codec**: round-trip for all ladder steps; parse rejects malformed strings ("a::m:5", "b:x:m:1", "a:abcdefgh:m:", non-numeric minutes, wrong hash length).
6. **Reconciler.merge**: never lowers; equal incoming = .noChange semantics (updatedAt unchanged).
7. **Staleness**: exact 36h boundary, nil lastFireAt, not-onboarded → false, nonzero recent days → false.
8. **Sealing**: end-of-day boundary in multiple time zones incl. DST transition days.

## Constraints
- Foundation only (seeded `RandomNumberGenerator` implemented locally; no swift-crypto needed here).
- No Date() inside logic — every function takes `now`/timestamps as parameters (testability).
- These types will run inside the DeviceActivityMonitor extension (~5–6MB memory cap): no caches, no large allocations, no Codable decoding of big resources in this module's hot path.
