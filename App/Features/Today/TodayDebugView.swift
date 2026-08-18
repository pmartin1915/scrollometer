import Foundation
import ScrollCore
import ScrollStore
import SwiftUI
import UIKit

/// M1 debug screen: drains the shared defaults bridge and shows today's raw minutes + estimated feet.
public struct TodayDebugView: View {
    @State private var perApp: [(tokenHash: String, minutes: Int)] = []
    @State private var totalFeet: Double = 0
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Per-app raw minutes (today)") {
                    if perApp.isEmpty {
                        Text("No usage data yet — numbers appear after the next threshold fires.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(perApp, id: \.tokenHash) { row in
                            HStack {
                                Text(row.tokenHash)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(row.minutes) min")
                            }
                        }
                    }
                }

                Section("Estimated distance") {
                    Text("At least ~\(totalFeet, specifier: "%.1f") ft")
                        .font(.title3)
                }

                if let errorMessage {
                    Section("Debug error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Today")
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        do {
            let database = try AppDatabase(url: AppGroup.databaseURL)
            let engine = try ConversionEngine(
                table: .bundled(),
                screen: DeviceScreenProvider.screenForCurrentDevice()
            )
            let bridge = SharedDefaultsBridge(database: database)
            _ = try bridge.drain(
                defaults: AppGroup.defaults,
                engine: engine,
                timeZoneID: TimeZone.current.identifier,
                now: Date()
            )

            let queries = StoreQueries(database: database)
            let today = DayKey(date: Date(), timeZone: .current)
            perApp = try queries.perAppMinutes(dayKey: today)
            totalFeet = try queries.todayTotalFeet(dayKey: today)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
