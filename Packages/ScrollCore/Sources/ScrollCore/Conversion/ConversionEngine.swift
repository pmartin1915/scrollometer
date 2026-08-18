import Foundation

/// Converts screen-time minutes into estimated physical scroll distance.
///
/// distance = minutes × screenHeightsPerMinute(profile) × physicalScreenHeight
///
/// Deterministic: no clock or randomness. Unknown profile IDs fall back to
/// the "other_text" profile.
public struct ConversionEngine: Sendable {
    public let table: VelocityTable
    public let screen: DeviceScreen

    public init(table: VelocityTable, screen: DeviceScreen) {
        self.table = table
        self.screen = screen
    }

    public func distance(minutes: Int, profileID: String) -> DistanceResult {
        let profile = table.profile(id: profileID)
            ?? table.profile(id: AppLabel.otherText.rawValue)
            ?? VelocityProfile(id: "hardcoded_fallback", screenHeightsPerMinute: 8.5, basis: "generic text feed fallback")
        let screenHeights = Double(minutes) * profile.screenHeightsPerMinute
        let feet = screenHeights * screen.physicalHeightInches / 12.0
        return DistanceResult(
            feet: feet,
            screenHeights: screenHeights,
            confidence: screen.confidence,
            tableVersion: table.version
        )
    }

    public func total(_ records: [(minutes: Int, profileID: String)]) -> DistanceResult {
        var feet = 0.0
        var screenHeights = 0.0
        for record in records {
            let r = distance(minutes: record.minutes, profileID: record.profileID)
            feet += r.feet
            screenHeights += r.screenHeights
        }
        return DistanceResult(feet: feet, screenHeights: screenHeights, confidence: screen.confidence, tableVersion: table.version)
    }
}
