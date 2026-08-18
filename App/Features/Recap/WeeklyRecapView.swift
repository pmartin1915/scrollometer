import Observation
import ScrollCore
import ScrollStore
import SwiftUI
import UniformTypeIdentifiers

/// Data needed to render a weekly recap card.
public struct RecapData: Identifiable {
    public let id = UUID()
    public let weekEnding: DayKey
    public let totalFeet: Double
    public let topApps: [(label: AppLabel, feet: Double)]
    public let bestLandmark: LandmarkComparisons.Comparison?
    public let priorWeekTotalFeet: Double?

    public var topApp: (label: AppLabel, feet: Double)? { topApps.first }

    public var weekOverWeekDeltaPercent: Double? {
        guard let prior = priorWeekTotalFeet, prior > 0 else { return nil }
        return ((totalFeet - prior) / prior) * 100
    }
}

/// Transferable wrapper for the rendered share-card PNG.
struct ShareableImage: Transferable, Sendable {
    let pngData: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
    }
}

/// Computes and displays the last complete Mon–Sun weekly recap.
public struct WeeklyRecapView: View {
    @State private var recap: RecapData?
    @State private var shareItem: ShareableImage?
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading recap…")
                } else if let recap {
                    recapContent(recap)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Recap")
        }
        .task { await load() }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let database = try AppDatabase(url: AppGroup.databaseURL)
            let computer = RecapComputer(database: database)
            let recap = try computer.lastCompleteWeekRecap(now: Date())

            self.recap = recap
            self.errorMessage = nil

            if let recap {
                let renderer = ShareCardRenderer()
                if let image = await renderer.renderedImage(week: recap, format: .story),
                   let data = image.pngData() {
                    shareItem = ShareableImage(pngData: data)
                }
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: - Subviews

    private func recapContent(_ recap: RecapData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Week ending \(recap.weekEnding.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text(DistanceFormatter.estimated(recap.totalFeet))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("estimated scrolling this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let delta = recap.weekOverWeekDeltaPercent {
                    HStack(spacing: 6) {
                        Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        Text("\(abs(delta), specifier: "%.0f")% vs last week")
                    }
                    .font(.headline)
                    .foregroundStyle(delta >= 0 ? .green : .red)
                }

                if let landmark = recap.bestLandmark {
                    Text("That's ~\(landmark.multiplier, specifier: "%.1f") \(landmark.landmarkName)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if let topApp = recap.topApp {
                    HStack {
                        Text("Top app")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(topApp.label.displayName) · \(DistanceFormatter.compact(topApp.feet))")
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let shareItem {
                    ShareLink(
                        item: shareItem,
                        preview: SharePreview(
                            "My week in scrolling",
                            image: Image(uiImage: UIImage(data: shareItem.pngData) ?? UIImage())
                        )
                    ) {
                        Label("Share card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No recap yet")
                .font(.title2)
            Text("Your first weekly recap unlocks after a full week of tracking.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}

// MARK: - RecapComputer

/// Reads sealed daily totals and aggregates a Mon–Sun recap.
struct RecapComputer {
    private let queries: StoreQueries

    init(database: AppDatabase) {
        self.queries = StoreQueries(database: database)
    }

    func lastCompleteWeekRecap(now: Date) throws -> RecapData? {
        guard let lastIntervalEnd = lastIntervalEnd() else { return nil }
        guard let (monday, sunday) = lastCompleteSealedWeek(now: now, lastIntervalEnd: lastIntervalEnd) else {
            return nil
        }

        let currentTotal = try totalFeet(from: monday, to: sunday)
        let topApps = try topApps(from: monday, to: sunday)
        let bestLandmark = LandmarkComparisons.best(forFeet: currentTotal)

        let calendar = Calendar.current
        let mondayDate = monday.endOfDay(timeZoneID: TimeZone.current.identifier).addingTimeInterval(-12 * 3600)
        let sundayDate = sunday.endOfDay(timeZoneID: TimeZone.current.identifier).addingTimeInterval(-12 * 3600)

        guard let priorMondayDate = calendar.date(byAdding: .day, value: -7, to: mondayDate),
              let priorSundayDate = calendar.date(byAdding: .day, value: -7, to: sundayDate) else {
            return nil
        }
        let priorMonday = DayKey(date: priorMondayDate, timeZone: .current)
        let priorSunday = DayKey(date: priorSundayDate, timeZone: .current)
        let priorTotal = try totalFeet(from: priorMonday, to: priorSunday)

        return RecapData(
            weekEnding: sunday,
            totalFeet: currentTotal,
            topApps: topApps,
            bestLandmark: bestLandmark,
            priorWeekTotalFeet: priorTotal > 0 ? priorTotal : nil
        )
    }

    // MARK: - Helpers

    private func lastCompleteSealedWeek(now: Date, lastIntervalEnd: Date) -> (monday: DayKey, sunday: DayKey)? {
        let calendar = Calendar.current
        let timeZoneID = TimeZone.current.identifier

        // Most recent Sunday that has already ended (today is never sealed).
        let weekday = calendar.component(.weekday, from: now)
        var daysBack = (weekday - 1 + 7) % 7
        if daysBack == 0 { daysBack = 7 }

        guard var sundayDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else { return nil }

        // Walk backwards one week at a time until all Mon–Sun days are sealed.
        for _ in 0..<52 {
            guard let mondayDate = calendar.date(byAdding: .day, value: -6, to: sundayDate) else { break }
            let monday = DayKey(date: mondayDate, timeZone: .current)
            let sunday = DayKey(date: sundayDate, timeZone: .current)

            let isComplete = daysInWeek(monday: mondayDate, sunday: sundayDate).allSatisfy { day in
                Reconciler.isSealed(
                    dayKey: day,
                    timeZoneID: timeZoneID,
                    lastIntervalEnd: lastIntervalEnd
                )
            }

            if isComplete {
                return (monday, sunday)
            }

            guard let previousSunday = calendar.date(byAdding: .day, value: -7, to: sundayDate) else { break }
            sundayDate = previousSunday
        }

        return nil
    }

    private func daysInWeek(monday: Date, sunday: Date) -> [DayKey] {
        let calendar = Calendar.current
        var days: [DayKey] = []
        var cursor = monday
        while cursor <= sunday {
            days.append(DayKey(date: cursor, timeZone: .current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private func totalFeet(from start: DayKey, to end: DayKey) throws -> Double {
        try queries.dailyTotals(range: start...end).map(\.feet).reduce(0, +)
    }

    private func topApps(from start: DayKey, to end: DayKey) throws -> [(label: AppLabel, feet: Double)] {
        let apps = try queries.trackedApps()
        let labelByHash = Dictionary(uniqueKeysWithValues: apps.map { ($0.tokenHash, $0.userLabel) })

        var totalsByLabel: [AppLabel: Double] = [:]

        let calendar = Calendar.current
        let startDate = start.endOfDay(timeZoneID: TimeZone.current.identifier).addingTimeInterval(-12 * 3600)
        let endDate = end.endOfDay(timeZoneID: TimeZone.current.identifier).addingTimeInterval(-12 * 3600)

        var cursor = startDate
        while cursor <= endDate {
            let key = DayKey(date: cursor, timeZone: .current)
            let rows = try queries.perAppFeet(dayKey: key)
            for row in rows {
                guard let label = labelByHash[row.tokenHash] else { continue }
                totalsByLabel[label, default: 0] += row.feet
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return totalsByLabel
            .map { (label: $0.key, feet: $0.value) }
            .sorted { $0.feet > $1.feet }
    }

    private func lastIntervalEnd() -> Date? {
        let timestamp = AppGroup.defaults.double(forKey: "meta.lastIntervalEnd")
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
