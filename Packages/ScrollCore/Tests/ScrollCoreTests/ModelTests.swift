import XCTest
@testable import ScrollCore

final class ModelTests: XCTestCase {
    // MARK: DayKey

    func testDayKeyDependsOnTimeZone() {
        // 2026-01-01T02:00:00Z is still 2025-12-31 in Chicago (UTC-6).
        let instant = ISO8601DateFormatter().date(from: "2026-01-01T02:00:00Z")!
        let utcKey = DayKey(date: instant, timeZone: TimeZone(identifier: "UTC")!)
        let chicagoKey = DayKey(date: instant, timeZone: TimeZone(identifier: "America/Chicago")!)
        XCTAssertEqual(utcKey.rawValue, "2026-01-01")
        XCTAssertEqual(chicagoKey.rawValue, "2025-12-31")
        XCTAssertLessThan(chicagoKey, utcKey)
    }

    func testDayKeyRawValueRoundTripAndValidation() {
        XCTAssertEqual(DayKey(rawValue: "2026-08-18")?.rawValue, "2026-08-18")
        XCTAssertNil(DayKey(rawValue: "2026-13-01"))
        XCTAssertNil(DayKey(rawValue: "2026-02-30"))
        XCTAssertNil(DayKey(rawValue: "garbage"))
        XCTAssertNil(DayKey(rawValue: "26-08-18"))
        XCTAssertNil(DayKey(rawValue: ""))
    }

    func testDayKeyCodableRoundTrip() throws {
        let key = DayKey(rawValue: "2026-08-18")!
        let data = try JSONEncoder().encode(key)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"2026-08-18\"")
        let decoded = try JSONDecoder().decode(DayKey.self, from: data)
        XCTAssertEqual(decoded, key)
        XCTAssertThrowsError(try JSONDecoder().decode(DayKey.self, from: Data("\"not-a-day\"".utf8)))
    }

    // MARK: TokenHasher

    func testTokenHasherIsStableAndWellFormed() {
        let hash = TokenHasher.hash(encodedToken: Data("example-token".utf8))
        XCTAssertEqual(hash.count, 16)
        XCTAssertTrue(hash.allSatisfy { "0123456789abcdef".contains($0) })
        XCTAssertEqual(hash, TokenHasher.hash(encodedToken: Data("example-token".utf8)), "must be deterministic")
        XCTAssertNotEqual(hash, TokenHasher.hash(encodedToken: Data("different-token".utf8)))
    }

    func testTokenHasherOutputParsesInEventNames() {
        let hash = TokenHasher.hash(encodedToken: Data("example-token".utf8))
        let name = ThresholdLadder.eventName(tokenHash: hash, minutes: 42)
        XCTAssertEqual(ThresholdLadder.parse(eventName: name)?.tokenHash, hash)
    }

    // MARK: TrackedApp / AppLabel

    func testTrackedAppDefaultsVelocityProfileFromLabel() {
        let app = TrackedApp(tokenHash: "0123456789abcdef", userLabel: .tiktok, sortOrder: 0)
        XCTAssertEqual(app.velocityProfileID, "tiktok")
        let other = TrackedApp(tokenHash: "0123456789abcdef", userLabel: .otherVideo, sortOrder: 1)
        XCTAssertEqual(other.velocityProfileID, "other_video")
    }

    func testAppLabelDisplayNames() {
        XCTAssertEqual(AppLabel.tiktok.displayName, "TikTok")
        XCTAssertEqual(AppLabel.otherVideo.displayName, "Other (video)")
        XCTAssertEqual(AppLabel.allCases.count, 7)
    }
}
