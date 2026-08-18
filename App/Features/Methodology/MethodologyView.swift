import ScrollCore
import SwiftUI

/// Renders the methodology from `docs/methodology.md`.
///
/// The velocity-profile numbers are read from `VelocityTable.bundled()` so the
/// in-app copy can never drift from the shipped table.
public struct MethodologyView: View {
    @State private var table: VelocityTable?
    @State private var loadError: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    honestFraming
                    formula
                    velocityTableSection
                    limitations
                    citations
                }
                .padding()
            }
            .navigationTitle("Methodology")
        }
        .onAppear { loadTable() }
    }

    private func loadTable() {
        do {
            table = try VelocityTable.bundled()
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }

    // MARK: - Subviews

    private var honestFraming: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimates, not measurements")
                .font(.title2)
                .fontWeight(.bold)

            Text("iOS does not allow any app to observe scrolling inside other apps. With your permission, Apple's Screen Time framework tells Scrollometer how much time you spend in the apps you choose to track. Everything is computed on your device; we never see your data.")
                .foregroundStyle(.secondary)
        }
    }

    private var formula: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The formula")
                .font(.title3)
                .fontWeight(.bold)

            Text("distance = minutes of use × screen-heights scrolled per minute × your screen's physical height")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("• Minutes of use come from Screen Time monitoring of the apps you selected.")
                Text("• Screen-heights per minute is a per-app velocity profile (below).")
                Text("• Your screen's physical height comes from your iPhone model.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var velocityTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Velocity profiles")
                .font(.title3)
                .fontWeight(.bold)

            if let table {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Profile").bold()
                        Text("Screen-heights/min").bold()
                        Text("Basis").bold()
                    }

                    ForEach(table.profiles, id: \.id) { profile in
                        GridRow {
                            Text(displayName(for: profile.id))
                            Text("\(profile.screenHeightsPerMinute, specifier: "%.1f")")
                                .monospacedDigit()
                            Text(profile.basis)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if let loadError {
                Text("Could not load velocity table: \(loadError)")
                    .foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
    }

    private var limitations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Known limitations")
                .font(.title3)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("• Minutes arrive in coarse buckets; brief sessions may undercount. All totals read “at least.”")
                Text("• Time in an app isn't all scrolling (typing, watching a full video). Velocity profiles are averages across real usage patterns, which is why they differ by app.")
                Text("• iOS occasionally drops monitoring events; Scrollometer detects stalls and offers a one-tap restart.")
                Text("• History is stored on-device only and does not sync across devices in v1.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var citations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("External reference points")
                .font(.title3)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("• Robertson, del Rosario & Van Bavel (2024) — peer-reviewed; average user scrolls ~300 ft/day.")
                Text("• Saucony × HarrisX (2024) — commercial survey; 78 miles/year (“three marathons”).")
                Text("• TollFreeForwarding (2023) — transparent-formula PR study; ~86 miles/year US average.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func displayName(for profileID: String) -> String {
        AppLabel(rawValue: profileID)?.displayName ?? profileID
    }
}
