import Foundation

/// User-assigned identity of a picked (opaque) app token.
public enum AppLabel: String, Codable, CaseIterable, Sendable {
    case tiktok, instagram, x, youtube, reddit
    case otherVideo = "other_video"
    case otherText = "other_text"

    /// The velocity profile that matches this label by default.
    public var defaultVelocityProfileID: String { rawValue }

    public var displayName: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .x: return "X"
        case .youtube: return "YouTube"
        case .reddit: return "Reddit"
        case .otherVideo: return "Other (video)"
        case .otherText: return "Other (text)"
        }
    }
}

/// A tracked app: opaque-token hash plus the user's label for it.
/// ScrollCore never sees ApplicationToken types — the app layer hashes the
/// encoded token via `TokenHasher` and stores the raw token itself.
public struct TrackedApp: Codable, Equatable, Sendable {
    public let tokenHash: String          // 16 lowercase hex chars (TokenHasher output)
    public var userLabel: AppLabel
    public var velocityProfileID: String
    public var sortOrder: Int

    public init(tokenHash: String, userLabel: AppLabel, velocityProfileID: String? = nil, sortOrder: Int) {
        self.tokenHash = tokenHash
        self.userLabel = userLabel
        self.velocityProfileID = velocityProfileID ?? userLabel.defaultVelocityProfileID
        self.sortOrder = sortOrder
    }
}

/// One day's high-water usage floor for one tracked app.
public struct UsageRecord: Codable, Equatable, Sendable {
    public let dayKey: DayKey
    public let tokenHash: String
    public var minutes: Int               // high-water floor, never decreases
    public let timeZoneID: String
    public var updatedAt: Date

    public init(dayKey: DayKey, tokenHash: String, minutes: Int, timeZoneID: String, updatedAt: Date) {
        self.dayKey = dayKey
        self.tokenHash = tokenHash
        self.minutes = minutes
        self.timeZoneID = timeZoneID
        self.updatedAt = updatedAt
    }
}

/// A computed scroll-distance estimate.
public struct DistanceResult: Equatable, Sendable {
    public enum Confidence: String, Codable, Sendable {
        case measured      // screen size from the device catalog
        case approximate   // screen size from the ppi fallback
    }

    public let feet: Double
    public let screenHeights: Double
    public let confidence: Confidence
    public let tableVersion: Int

    public var meters: Double { feet * 0.3048 }
    public var miles: Double { feet / 5280.0 }

    public init(feet: Double, screenHeights: Double, confidence: Confidence, tableVersion: Int) {
        self.feet = feet
        self.screenHeights = screenHeights
        self.confidence = confidence
        self.tableVersion = tableVersion
    }
}
