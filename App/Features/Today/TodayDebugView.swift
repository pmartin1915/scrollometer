import Observation
import ScrollCore
import ScrollStore
import SwiftUI
import UIKit

/// M1 debug screen: drains via the shared `TodayModel` so refresh logic is not
/// duplicated, then shows today's raw minutes + estimated feet.
public struct TodayDebugView: View {
    @Bindable var model: TodayModel

    public init(model: TodayModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Per-app raw minutes (today)") {
                    if model.debugPerAppMinutes.isEmpty {
                        Text("No usage data yet — numbers appear after the next threshold fires.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.debugPerAppMinutes, id: \.tokenHash) { row in
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
                    Text("At least \(model.formattedDistance(model.totalFeetToday))")
                        .font(.title3)
                }

                if let errorMessage = model.errorMessage {
                    Section("Debug error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Today")
        }
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            model.refresh()
        }
    }
}
