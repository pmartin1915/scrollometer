# WP2 — ScrollCore: domain models + ConversionEngine + data tables

## Goal
The product's core math, pure Foundation (Linux-testable), fully unit-tested. Distance = minutes × screenHeightsPerMinute × physical screen height.

## Types (Sources/ScrollCore/Models/)

```swift
public struct DayKey: Hashable, Codable, Comparable, Sendable {
    // "yyyy-MM-dd" in a given TimeZone; init(date:timeZone:), var rawValue: String
    // Comparable by chronology. Failable init(rawValue:).
}

public struct TrackedApp: Codable, Equatable, Sendable {
    public let tokenHash: String          // 16 hex chars (first 8 bytes of SHA256 of encoded token)
    public var userLabel: AppLabel
    public var velocityProfileID: String  // matches VelocityTable profile id
    public var sortOrder: Int
}

public enum AppLabel: String, Codable, CaseIterable, Sendable {
    case tiktok, instagram, x, youtube, reddit, otherVideo = "other_video", otherText = "other_text"
    public var defaultVelocityProfileID: String { rawValue }
    public var displayName: String
}

public struct UsageRecord: Codable, Equatable, Sendable {
    public let dayKey: DayKey
    public let tokenHash: String
    public var minutes: Int               // high-water floor
    public let timeZoneID: String
    public var updatedAt: Date
}

public struct DistanceResult: Equatable, Sendable {
    public let feet: Double
    public var meters: Double { feet * 0.3048 }
    public var miles: Double { feet / 5280 }
    public let screenHeights: Double
    public let confidence: Confidence     // .measured | .approximate (screen-catalog hit vs fallback)
    public let tableVersion: Int
}
```

## Conversion (Sources/ScrollCore/Conversion/)

```swift
public struct VelocityTable: Codable, Sendable {
    public let schemaVersion: Int
    public let version: Int
    public let profiles: [VelocityProfile]   // id, screenHeightsPerMinute: Double, basis: String
    public func profile(id: String) -> VelocityProfile?   // unknown id → nil; engine falls back to other_text
    public static func bundled() throws -> VelocityTable  // decodes Resources/velocity_table_v1.json
    // accept(remote:) -> VelocityTable : returns remote only if schemaVersion matches AND remote.version > self.version
}

public struct DeviceScreen: Sendable {
    public let physicalHeightInches: Double
    public let confidence: DistanceResult.Confidence
}

public enum DeviceScreenCatalog {
    // lookup(modelIdentifier:) -> DeviceScreen?  from Resources/device_screens_v1.json
    // fallback(nativePixelHeight:) -> DeviceScreen  using assumed 460 ppi, confidence .approximate
}

public struct ConversionEngine: Sendable {
    public init(table: VelocityTable, screen: DeviceScreen)
    public func distance(minutes: Int, profileID: String) -> DistanceResult
    public func total(_ records: [(minutes: Int, profileID: String)]) -> DistanceResult
}

public enum LandmarkComparisons {
    // Resources/landmarks_v1.json: [{id, name, feet, plural}] sorted ascending
    // best(forFeet:) -> Comparison? {name, multiplier} choosing the landmark whose multiplier lands in [1, 20],
    // preferring the largest landmark that still yields multiplier >= 1. nil below smallest*1.
    // Multiplier rounded to one decimal.
}
```

## Resources (Sources/ScrollCore/Resources/)

- `velocity_table_v1.json` — seed profiles: tiktok 7.1, instagram 6.5, youtube 4.5, x 9.0, reddit 8.0, other_video 6.0, other_text 8.5. Each with a `basis` string copied from `docs/methodology.md` table.
- `device_screens_v1.json` — model identifier → `{pointHeight, ppi, physicalHeightInches}` for iPhone 8 through iPhone 16 Pro Max class devices (research identifiers; ~30 entries; physicalHeightInches = nativePixelHeight/ppi computed correctly).
- `landmarks_v1.json` — Football field 300, Statue of Liberty 305, Eiffel Tower 1083, Empire State 1454, Burj Khalifa 2717, Golden Gate main span 4200, Mile 5280, Central Park length 13200, 5K 16404, Manhattan length 70752, Half marathon 69168, Marathon 138336 (feet; verify each number, order ascending; include singular/plural display forms).

## Tests (Tests/ScrollCoreTests/) — must pass `swift test` on Linux

1. **Engine math**: 60 min tiktok on a 5.81 in screen ⇒ 7.1×60 = 426 screen-heights ⇒ 426×5.81/12 ≈ 206 ft... **executor note: compute expected values from the formula, don't copy this arithmetic blindly; the plan-level sanity target is 60 min TikTok on a 6.1" phone ≈ 340–420 ft — if the formula yields outside that band, flag it in the PR description rather than tuning constants silently.**
2. Unit round-trips: feet↔meters↔miles.
3. Monotonicity property: distance strictly increases with minutes for every profile.
4. Unknown profile id falls back to other_text.
5. VelocityTable version gating: older/same-version and schema-mismatched remotes rejected.
6. DeviceScreenCatalog: known identifier hit (confidence .measured); unknown identifier fallback (confidence .approximate); JSON decodes fully.
7. LandmarkComparisons: boundary cases (just below/above thresholds, multiplier windows, very large totals pick big landmarks).
8. DayKey: timezone correctness (same instant, different tz → different keys across midnight), Comparable ordering, rawValue round-trip.
9. All three bundled JSONs decode without error (resource-loading test).

## Constraints
- Foundation + swift-crypto only. No UIKit/SwiftUI (DeviceScreenCatalog takes the model identifier/pixel height as INPUT — callers in the app layer read UIScreen/utsname).
- Public API documented with /// comments. Deterministic: no Date()/random in engine logic.
