import ScrollCore
import SwiftUI

/// Fixed-size story (1080×1920) or square (1080×1080) share card.
public enum ShareCardFormat {
    case story
    case square

    public var size: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

public struct ShareCardView: View {
    let week: RecapData
    let format: ShareCardFormat

    public init(week: RecapData, format: ShareCardFormat) {
        self.week = week
        self.format = format
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.1, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: format == .story ? 56 : 40) {
                header
                distanceBlock

                if let landmark = week.bestLandmark {
                    landmarkLine(landmark)
                }

                Spacer()

                topAppsSection

                Spacer()

                footer
            }
            .padding(format == .story ? 80 : 64)
        }
        .frame(width: format.size.width, height: format.size.height)
        .foregroundStyle(.white)
    }

    // MARK: - Subviews

    private var header: some View {
        Text("SCROLLOMETER")
            .font(.system(size: format == .story ? 28 : 24, weight: .semibold, design: .rounded))
            .tracking(6)
            .opacity(0.8)
    }

    private var distanceBlock: some View {
        VStack(spacing: 16) {
            Text(DistanceFormatter.estimated(week.totalFeet))
                .font(.system(
                    size: format == .story ? 220 : 170,
                    weight: .bold,
                    design: .rounded
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.3)

            Text("of scrolling this week")
                .font(.system(size: format == .story ? 40 : 32, weight: .medium))
                .opacity(0.9)
        }
        .multilineTextAlignment(.center)
    }

    private func landmarkLine(_ comparison: LandmarkComparisons.Comparison) -> some View {
        Text("That's ~\(comparison.multiplier, specifier: "%.1f") \(comparison.landmarkName)")
            .font(.system(size: format == .story ? 40 : 32, weight: .medium))
            .opacity(0.9)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }

    private var topAppsSection: some View {
        let top3 = Array(week.topApps.prefix(3))

        return Group {
            if top3.isEmpty {
                EmptyView()
            } else {
                let maxFeet = max(top3.map(\.feet).max() ?? 1.0, 1.0)

                VStack(alignment: .leading, spacing: format == .story ? 28 : 20) {
                    Text("Top apps")
                        .font(.system(size: format == .story ? 32 : 26, weight: .semibold))
                        .opacity(0.8)

                    ForEach(top3, id: \.label) { row in
                        HStack(spacing: 16) {
                            Text(row.label.displayName)
                                .font(.system(size: format == .story ? 32 : 26))
                                .frame(width: format == .story ? 220 : 180, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            GeometryReader { geometry in
                                Capsule()
                                    .frame(
                                        width: max(0, geometry.size.width * CGFloat(row.feet / maxFeet)),
                                        height: format == .story ? 24 : 20,
                                        alignment: .leading
                                    )
                            }
                            .frame(height: format == .story ? 24 : 20)

                            Text(DistanceFormatter.compact(row.feet))
                                .font(.system(size: format == .story ? 28 : 22))
                                .monospacedDigit()
                                .frame(width: format == .story ? 140 : 110, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        Text("estimated · scrollometer")
            .font(.system(size: format == .story ? 28 : 24, weight: .medium))
            .opacity(0.6)
    }
}
