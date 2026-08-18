import Foundation
import Observation
import ScrollCore
import ScrollStore
import SwiftUI
import WidgetKit

/// Shared owner of the "today" data pipeline.
///
/// Encapsulates the drain/refresh logic previously living in
/// `TodayDebugView` and exposes display-ready values for the dashboard,
/// debug screen, and widget.
@Observable
public final class TodayModel {
    public private(set) var perAppFeet: [(label: AppLabel, feet: Double)] = []
    public private(set) var totalFeetToday: Double = 0
    public private(set) var landmark: LandmarkComparisons.Comparison? = nil
    public private(set) var streakDays: Int = 0
    public private(set) var debugPerAppMinutes: [(tokenHash: String, minutes: Int)] = []
    public private(set) var errorMessage: String? = nil

    private let database: AppDatabase
    private let queries: StoreQueries
    private let engine: ConversionEngine
    private let bridge: SharedDefaultsBridge

    @MainActor
    public init(database: AppDatabase) throws {
        self.database = database
        self.queries = StoreQueries(database: database)
        self.engine = try ConversionEngine(
            table: .bundled(),
            screen: DeviceScreenProvider.screenForCurrentDevice()
        )
        self.bridge = SharedDefaultsBridge(database: database)
    }

    /// Drains the shared defaults bridge, refreshes every exposed value, and
    /// asks the widget timeline to reload.
    public func refresh() {
        do {
            let now = Date()
            let timeZoneID = TimeZone.current.identifier

            _ = try bridge.drain(
                defaults: AppGroup.defaults,
                engine: engine,
                timeZoneID: timeZoneID,
                now: now
            )

            let today = DayKey(date: now, timeZone: .current)
            let apps = try queries.trackedApps()
            let labelByHash = Dictionary(
                uniqueKeysWithValues: apps.map { ($0.tokenHash, $0.userLabel) }
            )

            let todayRows = try queries.perAppFeet(dayKey: today)
            perAppFeet = todayRows
                .compactMap { row in
                    guard let label = labelByHash[row.tokenHash] else { return nil }
                    return (label: label, feet: row.feet)
                }
                .sorted { $0.feet > $1.feet }

            totalFeetToday = try queries.todayTotalFeet(dayKey: today)
            landmark = LandmarkComparisons.best(forFeet: totalFeetToday)
            streakDays = try computeStreak(now: now, timeZoneID: timeZoneID)
            debugPerAppMinutes = try queries.perAppMinutes(dayKey: today)
            errorMessage = nil

            Task { @MainActor in
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Display helper used by dashboard and debug views.
    public func formattedDistance(_ feet: Double) -> String {
        DistanceFormatter.estimated(feet)
    }

    // MARK: - Streak

    private func computeStreak(now: Date, timeZoneID: String) throws -> Int {
        guard let lastIntervalEnd = lastIntervalEnd() else { return 0 }

        let calendar = Calendar.current
        guard let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now) else {
            return 0
        }

        guard let startDate = calendar.date(byAdding: .day, value: -365, to: yesterdayDate) else {
            return 0
        }
        let startKey = DayKey(date: startDate, timeZone: .current)
        let yesterdayKey = DayKey(date: yesterdayDate, timeZone: .current)

        let totals = try queries.dailyTotals(range: startKey...yesterdayKey)
        let totalsByDay = Dictionary(uniqueKeysWithValues: totals.map { ($0.dayKey, $0.feet) })

        var streak = 0
        var cursorDate = yesterdayDate
        var cursorKey = yesterdayKey

        while cursorKey >= startKey {
            let sealed = Reconciler.isSealed(
                dayKey: cursorKey,
                timeZoneID: timeZoneID,
                lastIntervalEnd: lastIntervalEnd
            )
            let total = totalsByDay[cursorKey] ?? 0
            guard sealed && total > 0 else { break }

            streak += 1
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: cursorDate) else { break }
            cursorDate = previousDate
            cursorKey = DayKey(date: cursorDate, timeZone: .current)
        }

        return streak
    }

    private func lastIntervalEnd() -> Date? {
        let timestamp = AppGroup.defaults.double(forKey: "meta.lastIntervalEnd")
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
