import Observation
import ScrollCore
import ScrollStore
import SwiftUI
import UIKit

/// The main Today dashboard: big odometer, per-app bars, streak, and links to
/// methodology / settings.
public struct TodayDashboardView: View {
    @Bindable var model: TodayModel

    public init(model: TodayModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if model.totalFeetToday == 0 && model.perAppFeet.isEmpty {
                        emptyState
                    } else {
                        odometerSection

                        if let landmark = model.landmark {
                            landmarkLine(landmark)
                        }

                        perAppBars

                        if model.streakDays > 0 {
                            streakRow
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scrollometer")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        MethodologyView()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(model: model)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            model.refresh()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No data yet")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("First numbers appear within about an hour of scrolling.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var odometerSection: some View {
        VStack(spacing: 8) {
            Text(model.formattedDistance(model.totalFeetToday))
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("estimated scroll distance today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func landmarkLine(_ comparison: LandmarkComparisons.Comparison) -> some View {
        Text("That's ~\(comparison.multiplier, specifier: "%.1f") \(comparison.landmarkName)")
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var perAppBars: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Per app today")
                .font(.headline)

            let maxFeet = max(model.perAppFeet.map(\.feet).max() ?? 1.0, 1.0)

            ForEach(model.perAppFeet, id: \.label) { row in
                HStack(spacing: 12) {
                    Text(row.label.displayName)
                        .frame(width: 100, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geometry in
                        Capsule()
                            .frame(
                                width: max(0, geometry.size.width * CGFloat(row.feet / maxFeet)),
                                height: 12,
                                alignment: .leading
                            )
                    }
                    .frame(height: 12)

                    Text(model.formattedDistance(row.feet))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 72, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakRow: some View {
        HStack(spacing: 8) {
            Text("🔥")
                .font(.title2)
            Text("\(model.streakDays)-day streak")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
