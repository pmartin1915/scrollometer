import Foundation

/// Outcome of applying one threshold event.
public enum RecordOutcome: Equatable, Sendable {
    case applied        // raised the floor
    case noChange       // duplicate or lower than current floor
    case rejectedZero   // reported <= 0 minutes (iOS 26.2 zero-minutes bug defense)
    case clamped        // reported > 1440; clamped to 1440 and applied if higher
}

/// Idempotent per-day usage floors built from cumulative threshold events.
///
/// Every DeviceActivity threshold event is a statement "app X has used >= N
/// minutes today", so the correct merge is max(), never increment: duplicate
/// fires are no-ops and missed fires self-heal when any later event lands.
/// Runs inside the DeviceActivityMonitor extension (~5-6 MB memory cap):
/// no caches, no resource decoding, dictionary ops only.
public struct HighWaterAccumulator: Sendable {
    public private(set) var dayKey: DayKey
    public private(set) var minutes: [String: Int]   // 16-hex tokenHash → floor minutes

    public init(dayKey: DayKey, existing: [String: Int] = [:]) {
        self.dayKey = dayKey
        self.minutes = existing
    }

    @discardableResult
    public mutating func record(tokenHash: String, reportedMinutes: Int) -> RecordOutcome {
        guard reportedMinutes > 0 else { return .rejectedZero }
        let clamped = min(reportedMinutes, 1440)
        let current = minutes[tokenHash] ?? 0
        if clamped > current {
            minutes[tokenHash] = clamped
            return reportedMinutes > 1440 ? .clamped : .applied
        }
        return reportedMinutes > 1440 ? .clamped : .noChange
    }
}
