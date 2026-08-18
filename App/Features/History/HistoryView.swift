import Charts
import ScrollCore
import ScrollStore
import SwiftUI

extension DayKey: Plottable {
    public var primitivePlottable: String { rawValue }

    public init?(primitivePlottable: String) {
        self.init(rawValue: primitivePlottable)
    }
}

/// 14-day daily totals chart + list.
public struct HistoryView: View {
    @State private var entries: [(dayKey: DayKey, feet: Double)] = []
    @State private var selectedDay: DayKey? = nil
    @State private var errorMessage: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let selected = selectedEntry {
                        Text("\(selected.dayKey.rawValue): at least \(DistanceFormatter.compact(selected.feet))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    chart

                    list
                }
                .padding()
            }
            .navigationTitle("History")
        }
        .onAppear { load() }
    }

    // MARK: - Data

    private var selectedEntry: (dayKey: DayKey, feet: Double)? {
        guard let selectedDay else { return nil }
        return entries.first { $0.dayKey == selectedDay }
    }

    private func load() {
        do {
            let database = try AppDatabase(url: AppGroup.databaseURL)
            let queries = StoreQueries(database: database)

            let calendar = Calendar.current
            let now = Date()
            let today = DayKey(date: now, timeZone: .current)

            guard let startDate = calendar.date(byAdding: .day, value: -13, to: now) else { return }
            let startKey = DayKey(date: startDate, timeZone: .current)

            let totals = try queries.dailyTotals(range: startKey...today)
            let totalsByDay = Dictionary(uniqueKeysWithValues: totals.map { ($0.dayKey, $0.feet) })

            var days: [(dayKey: DayKey, feet: Double)] = []
            var cursor = startDate
            for _ in 0..<14 {
                let key = DayKey(date: cursor, timeZone: .current)
                days.append((key, totalsByDay[key] ?? 0))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }

            entries = days
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: - Subviews

    private var chart: some View {
        Chart(entries, id: \.dayKey) { entry in
            BarMark(
                x: .value("Day", entry.dayKey),
                y: .value("Feet", entry.feet)
            )
            .foregroundStyle(entry.dayKey == selectedDay ? Color.accentColor : Color.blue)
            .cornerRadius(4)
        }
        .chartXSelection(value: $selectedDay)
        .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom, values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let day = value.as(DayKey.self) {
                        Text(shortWeekday(day))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 14 days")
                .font(.headline)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                ForEach(entries.reversed(), id: \.dayKey) { entry in
                    HStack {
                        Text(entry.dayKey.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Text(DistanceFormatter.compact(entry.feet))
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func shortWeekday(_ dayKey: DayKey) -> String {
        // Midday of the day gives a stable weekday even near DST transitions.
        let reference = dayKey.endOfDay(timeZoneID: TimeZone.current.identifier)
            .addingTimeInterval(-12 * 3600)
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: reference)
    }
}
