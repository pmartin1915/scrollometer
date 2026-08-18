import WidgetKit
import SwiftUI

struct DistanceEntry: TimelineEntry {
    let date: Date
    let distanceFeet: Double
}

struct DistanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> DistanceEntry {
        DistanceEntry(date: Date(), distanceFeet: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (DistanceEntry) -> Void) {
        completion(DistanceEntry(date: Date(), distanceFeet: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DistanceEntry>) -> Void) {
        let entry = DistanceEntry(date: Date(), distanceFeet: 0)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct DailyDistanceWidgetEntryView: View {
    var entry: DistanceProvider.Entry

    var body: some View {
        Text("— ft")
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
        .supportedFamilies([.systemSmall])
    }
}

@main
struct OdoWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyDistanceWidget()
    }
}
