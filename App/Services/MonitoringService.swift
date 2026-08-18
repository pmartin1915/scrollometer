import DeviceActivity
import FamilyControls
import Foundation
import ScrollCore

/// Starts and stops the daily Screen Time threshold monitoring session.
public final class MonitoringService {
    public static let shared = MonitoringService()

    private let center = DeviceActivityCenter()
    private let encoder = JSONEncoder()

    private init() {}

    /// True if at least one DeviceActivity monitoring session is active.
    public var isMonitoring: Bool {
        !center.activities.isEmpty
    }

    /// Begins monitoring every application token in `selection` against all ladder thresholds.
    public func startMonitoring(selection: FamilyActivitySelection, config: LadderConfig) throws {
        let steps = ThresholdLadder.steps(config: config)
        let tokens = Array(selection.applicationTokens)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        events.reserveCapacity(steps.count * tokens.count)

        for token in tokens {
            let tokenData = try encoder.encode(token)
            let hash = TokenHasher.hash(encodedToken: tokenData)

            for minutes in steps {
                let name = ThresholdLadder.eventName(tokenHash: hash, minutes: minutes)
                let event = DeviceActivityEvent(
                    applications: Set([token]),
                    threshold: DateComponents(minute: minutes)
                )
                events[DeviceActivityEvent.Name(name)] = event
            }
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        try center.startMonitoring(.init("daily"), during: schedule, events: events)
    }

    public func stopMonitoring() {
        center.stopMonitoring()
    }

    public func restartMonitoring(selection: FamilyActivitySelection, config: LadderConfig) throws {
        stopMonitoring()
        try startMonitoring(selection: selection, config: config)
    }

    /// Restarts monitoring if it has stopped (e.g. after an app update or crash).
    public func ensureMonitoring(selection: FamilyActivitySelection, config: LadderConfig) throws {
        guard !isMonitoring else { return }
        try restartMonitoring(selection: selection, config: config)
    }
}
