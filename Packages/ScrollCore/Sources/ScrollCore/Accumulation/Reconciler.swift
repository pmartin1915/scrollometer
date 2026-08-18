import Foundation

/// Merge and health heuristics for the noisy threshold pipeline.
public enum Reconciler {
    /// MAX-semantics upsert into the main store. Never lowers a floor;
    /// `updatedAt` refreshes only when the floor actually rises.
    /// Incoming minutes are clamped to 1440.
    public static func merge(
        existing: UsageRecord?,
        incomingMinutes: Int,
        at now: Date,
        dayKey: DayKey,
        tokenHash: String,
        timeZoneID: String
    ) -> UsageRecord {
        let incoming = min(max(incomingMinutes, 0), 1440)
        guard var record = existing else {
            return UsageRecord(dayKey: dayKey, tokenHash: tokenHash, minutes: incoming, timeZoneID: timeZoneID, updatedAt: now)
        }
        if incoming > record.minutes {
            record.minutes = incoming
            record.updatedAt = now
        }
        return record
    }

    /// Tracking-stall detection (drives the "tracking hiccup" repair banner).
    ///
    /// `recentDaysAllZero` is computed by the CALLER: true iff today's and
    /// yesterday's total minutes across all tracked apps are both zero.
    /// Stale iff onboarded AND recent days are all zero AND the last threshold
    /// fire is unknown or strictly older than 36 hours.
    public static func isStale(
        lastFireAt: Date?,
        now: Date,
        hasCompletedOnboarding: Bool,
        recentDaysAllZero: Bool
    ) -> Bool {
        guard hasCompletedOnboarding, recentDaysAllZero else { return false }
        guard let lastFireAt else { return true }
        return now.timeIntervalSince(lastFireAt) > 36 * 3600
    }

    /// A day is sealed once the monitoring interval has ended at or after the
    /// first instant of the NEXT calendar day in the record's time zone.
    /// Sealed days are final: recaps and streaks use only sealed days.
    public static func isSealed(dayKey: DayKey, timeZoneID: String, lastIntervalEnd: Date?) -> Bool {
        guard let lastIntervalEnd else { return false }
        return lastIntervalEnd >= dayKey.endOfDay(timeZoneID: timeZoneID)
    }
}
