import ScrollCore
import ScrollStore
import SwiftUI
import WidgetKit

struct DistanceEntry: TimelineEntry {
    let date: Date
    let distanceFeet: Double
    let isPlaceholder: Bool
}

struct DistanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> DistanceEntry {
        DistanceEntry(date: Date(), distanceFeet: 0, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DistanceEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DistanceEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Date().addingTimeInterval(30 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Read-only access to the shared distance cache

    private func readEntry() -> DistanceEntry {
        // Never create the database from the widget process. If the app hasn't
        // run yet, fall back to the placeholder instead of triggering migrations.
        guard FileManager.default.fileExists(atPath: AppGroup.databaseURL.path) else {
            return placeholderEntry()
        }

        do {
            let database = try AppDatabase(url: AppGroup.databaseURL)
            let queries = StoreQueries(database: database)
            let today = DayKey(date: Date(), timeZone: .current)
            let feet = try queries.todayTotalFeet(dayKey: today)
            return DistanceEntry(date: Date(), distanceFeet: feet, isPlaceholder: false)
        } catch {
            return placeholderEntry()
        }
    }

    private func placeholderEntry() -> DistanceEntry {
        DistanceEntry(date: Date(), distanceFeet: 0, isPlaceholder: true)
    }
}

struct DailyDistanceWidgetEntryView: View {
    var entry: DistanceProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 4) {
            if entry.isPlaceholder || entry.distanceFeet <= 0 {
                Text("— ft")
                    .font(.headline)
            } else {
                Text(WidgetDistanceFormatter.compact(entry.distanceFeet))
                    .font(.system(.title2, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var circularView: some View {
        VStack(spacing: 2) {
            if entry.isPlaceholder || entry.distanceFeet <= 0 {
                Text("—")
                    .font(.headline)
                Text("ft")
                    .font(.caption2)
            } else {
                Text(WidgetDistanceFormatter.compact(entry.distanceFeet))
                    .font(.headline)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }

    private var inlineView: some View {
        if entry.isPlaceholder || entry.distanceFeet <= 0 {
            Text("— ft scrolled")
        } else {
            Text("~\(WidgetDistanceFormatter.compact(entry.distanceFeet)) scrolled")
        }
    }
}

struct DailyDistanceWidget: Widget {
    let kind: String = "DailyDistanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DistanceProvider()) { entry in
            DailyDistanceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Distance")
        .description("Shows today's estimated scroll distance.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

@main
struct OdoWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyDistanceWidget()
    }
}

// MARK: - Formatting

private enum WidgetDistanceFormatter {
    static func compact(_ feet: Double) -> String {
        if feet < 5280 {
            return "\(Int(feet.rounded())) ft"
        } else {
            return String(format: "%.1f mi", feet / 5280.0)
        }
    }
}
