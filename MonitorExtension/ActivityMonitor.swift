import DeviceActivity
import Foundation
import ScrollCore

/// DeviceActivity monitor extension that receives threshold events and writes
/// high-water usage floors into the shared App Group `UserDefaults`.
///
/// This type intentionally uses only `DeviceActivity`, `Foundation`, and
/// `ScrollCore`: no GRDB, no SwiftUI, and no resource decoding.
class ActivityMonitor: DeviceActivityMonitor {

    private enum Key {
        static let usagePrefix = "usage.v1."
        static let currentDayKey = "meta.currentDayKey"
        static let lastFireAt = "meta.lastFireAt"
        static let lastIntervalEnd = "meta.lastIntervalEnd"
    }

    private let defaults = AppGroup.defaults

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        let today = DayKey(date: Date(), timeZone: .current)
        defaults.set(today.rawValue, forKey: Key.currentDayKey)
        pruneUsageKeys(keepingSince: today)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastIntervalEnd)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard let (tokenHash, minutes) = ThresholdLadder.parse(eventName: event.rawValue) else { return }

        let dayKey = DayKey(date: Date(), timeZone: .current)
        let usageKey = Key.usagePrefix + dayKey.rawValue
        let existing = defaults.dictionary(forKey: usageKey) as? [String: Int] ?? [:]

        var accumulator = HighWaterAccumulator(dayKey: dayKey, existing: existing)
        let outcome = accumulator.record(tokenHash: tokenHash, reportedMinutes: minutes)

        if outcome == .applied || outcome == .clamped {
            defaults.set(accumulator.minutes, forKey: usageKey)
        }

        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastFireAt)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastIntervalEnd)
    }

    /// Removes `usage.v1.<dayKey>` snapshots older than 8 days, comparing ISO day keys.
    private func pruneUsageKeys(keepingSince today: DayKey) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        guard let cutoffDate = calendar.date(byAdding: .day, value: -8, to: Date()) else { return }
        let cutoff = DayKey(date: cutoffDate, timeZone: .current)

        for key in defaults.dictionaryRepresentation().keys {
            guard key.hasPrefix(Key.usagePrefix) else { continue }
            let rawDay = String(key.dropFirst(Key.usagePrefix.count))
            guard let keyDay = DayKey(rawValue: rawDay) else { continue }
            if keyDay < cutoff {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
