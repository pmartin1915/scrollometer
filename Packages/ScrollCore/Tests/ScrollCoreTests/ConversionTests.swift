import XCTest
@testable import ScrollCore

final class ConversionTests: XCTestCase {
    private func makeEngine(heightInches: Double = 5.81, confidence: DistanceResult.Confidence = .measured) throws -> ConversionEngine {
        ConversionEngine(
            table: try VelocityTable.bundled(),
            screen: DeviceScreen(physicalHeightInches: heightInches, confidence: confidence)
        )
    }

    func testTikTokHourMatchesFormula() throws {
        let engine = try makeEngine(heightInches: 5.81)
        let result = engine.distance(minutes: 60, profileID: "tiktok")
        // 60 min × 7.1 screens/min = 426 screens; 426 × 5.81 in / 12 = 206.255 ft
        XCTAssertEqual(result.screenHeights, 426.0, accuracy: 0.01)
        XCTAssertEqual(result.feet, 206.255, accuracy: 0.01)
        XCTAssertEqual(result.confidence, .measured)
        XCTAssertEqual(result.tableVersion, 1)
    }

    func testUnitRoundTrips() throws {
        let engine = try makeEngine()
        let result = engine.distance(minutes: 123, profileID: "x")
        XCTAssertEqual(result.meters, result.feet * 0.3048, accuracy: 0.001)
        XCTAssertEqual(result.miles, result.feet / 5280.0, accuracy: 0.001)
        XCTAssertEqual(result.miles * 5280.0, result.feet, accuracy: 0.01)
    }

    func testDistanceMonotonicInMinutesForEveryProfile() throws {
        let table = try VelocityTable.bundled()
        let engine = try makeEngine()
        for profile in table.profiles {
            var last = -1.0
            for minutes in [0, 1, 5, 30, 60, 240, 1440] {
                let feet = engine.distance(minutes: minutes, profileID: profile.id).feet
                XCTAssertGreaterThan(feet, last, "profile \(profile.id) not monotonic")
                last = feet
            }
        }
    }

    func testUnknownProfileFallsBackToOtherText() throws {
        let engine = try makeEngine()
        let unknown = engine.distance(minutes: 10, profileID: "does_not_exist")
        let otherText = engine.distance(minutes: 10, profileID: "other_text")
        XCTAssertEqual(unknown.feet, otherText.feet, accuracy: 0.001)
    }

    func testTotalSumsComponents() throws {
        let engine = try makeEngine()
        let a = engine.distance(minutes: 30, profileID: "tiktok")
        let b = engine.distance(minutes: 45, profileID: "reddit")
        let total = engine.total([(30, "tiktok"), (45, "reddit")])
        XCTAssertEqual(total.feet, a.feet + b.feet, accuracy: 0.001)
        XCTAssertEqual(total.screenHeights, a.screenHeights + b.screenHeights, accuracy: 0.001)
    }

    func testDailyMixIsPlausibleAgainstPublishedAggregate() throws {
        // Robertson et al. 2024: average social-feed user ≈ 300 ft/day.
        // A 2-hour mixed day on a 6.1" phone should land in the low hundreds
        // of feet — same order of magnitude, not 10x off in either direction.
        let engine = try makeEngine(heightInches: 5.56)
        let total = engine.total([(60, "tiktok"), (30, "instagram"), (30, "x")])
        XCTAssertGreaterThan(total.feet, 100)
        XCTAssertLessThan(total.feet, 1000)
    }

    // MARK: VelocityTable gating

    func testBundledTableHasAllSevenProfiles() throws {
        let table = try VelocityTable.bundled()
        XCTAssertEqual(table.profiles.count, 7)
        for label in AppLabel.allCases {
            XCTAssertNotNil(table.profile(id: label.defaultVelocityProfileID), "missing profile for \(label)")
        }
    }

    func testAcceptRejectsSameAndOlderVersions() throws {
        let bundled = try VelocityTable.bundled()
        let sameVersionDifferentContent = VelocityTable(schemaVersion: 1, version: bundled.version, profiles: [])
        XCTAssertEqual(bundled.accept(remote: sameVersionDifferentContent), bundled)
        let older = VelocityTable(schemaVersion: 1, version: bundled.version - 1, profiles: [])
        XCTAssertEqual(bundled.accept(remote: older), bundled)
    }

    func testAcceptRejectsSchemaMismatch() throws {
        let bundled = try VelocityTable.bundled()
        let newerWrongSchema = VelocityTable(schemaVersion: 2, version: bundled.version + 1, profiles: [])
        XCTAssertEqual(bundled.accept(remote: newerWrongSchema), bundled)
    }

    func testAcceptTakesStrictUpgrade() throws {
        let bundled = try VelocityTable.bundled()
        let upgrade = VelocityTable(schemaVersion: 1, version: bundled.version + 1, profiles: bundled.profiles)
        XCTAssertEqual(bundled.accept(remote: upgrade).version, bundled.version + 1)
    }

    // MARK: DeviceScreenCatalog

    func testCatalogSpotChecks() {
        // Notch era, Dynamic Island era, Max-size.
        XCTAssertEqual(DeviceScreenCatalog.lookup(modelIdentifier: "iPhone12,1")?.physicalHeightInches ?? 0, 5.5, accuracy: 0.01)
        XCTAssertEqual(DeviceScreenCatalog.lookup(modelIdentifier: "iPhone15,2")?.physicalHeightInches ?? 0, 5.56, accuracy: 0.01)
        XCTAssertEqual(DeviceScreenCatalog.lookup(modelIdentifier: "iPhone17,2")?.physicalHeightInches ?? 0, 6.23, accuracy: 0.01)
        XCTAssertEqual(DeviceScreenCatalog.lookup(modelIdentifier: "iPhone15,2")?.confidence, .measured)
    }

    func testCatalogUnknownIdentifierAndFallback() {
        XCTAssertNil(DeviceScreenCatalog.lookup(modelIdentifier: "iPhone99,9"))
        let fallback = DeviceScreenCatalog.fallback(nativePixelHeight: 2556)
        XCTAssertEqual(fallback.physicalHeightInches, 2556.0 / 460.0, accuracy: 0.001)
        XCTAssertEqual(fallback.confidence, .approximate)
    }

    func testCatalogEntriesAreSelfConsistent() throws {
        // physicalHeightInches must equal nativePixelHeight / ppi within rounding.
        let catalog = try DeviceScreenCatalog.loadCatalog()
        XCTAssertGreaterThanOrEqual(catalog.devices.count, 30)
        for device in catalog.devices {
            let derived = Double(device.nativePixelHeight) / Double(device.ppi)
            XCTAssertEqual(device.physicalHeightInches, derived, accuracy: 0.01, "inconsistent entry \(device.identifier)")
        }
    }

    // MARK: Landmarks

    func testLandmarkSelection() {
        XCTAssertNil(LandmarkComparisons.best(forFeet: 299))
        let field = LandmarkComparisons.best(forFeet: 300)
        XCTAssertEqual(field?.landmarkName, "football field")
        XCTAssertEqual(field?.multiplier ?? 0, 1.0, accuracy: 0.001)

        let liberty = LandmarkComparisons.best(forFeet: 650)
        XCTAssertEqual(liberty?.landmarkName, "Statues of Liberty")
        XCTAssertEqual(liberty?.multiplier ?? 0, 2.1, accuracy: 0.001)

        let miles = LandmarkComparisons.best(forFeet: 6000)
        XCTAssertEqual(miles?.landmarkName, "miles")
        XCTAssertEqual(miles?.multiplier ?? 0, 1.1, accuracy: 0.001)

        let marathons = LandmarkComparisons.best(forFeet: 1_000_000)
        XCTAssertEqual(marathons?.landmarkName, "marathons")
        XCTAssertEqual(marathons?.multiplier ?? 0, 7.2, accuracy: 0.001)
    }

    func testLandmarkSingularOnRoundedOne() {
        // 310 ft / 305 = 1.016 → rounds to 1.0 → singular name.
        let comparison = LandmarkComparisons.best(forFeet: 310)
        XCTAssertEqual(comparison?.landmarkName, "Statue of Liberty")
        XCTAssertEqual(comparison?.multiplier ?? 0, 1.0, accuracy: 0.001)
    }

    func testLandmarksFileIsSortedAscending() throws {
        let landmarks = try LandmarkComparisons.loadLandmarks()
        XCTAssertEqual(landmarks.map(\.feet), landmarks.map(\.feet).sorted())
        XCTAssertGreaterThanOrEqual(landmarks.count, 10)
    }
}
