import Foundation
import GRDB
import ScrollCore

/// GRDB persistence row for a tracked app.
public struct TrackedAppRecord: Codable, FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "tracked_app" }

    public var tokenHash: String
    public var tokenData: Data
    public var userLabel: String
    public var velocityProfileID: String
    public var sortOrder: Int
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case tokenHash = "token_hash"
        case tokenData = "token_data"
        case userLabel = "user_label"
        case velocityProfileID = "velocity_profile_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    /// Creates a record from the domain model plus persisted token bytes.
    public init(domain: TrackedApp, tokenData: Data, createdAt: Date) {
        self.tokenHash = domain.tokenHash
        self.tokenData = tokenData
        self.userLabel = domain.userLabel.rawValue
        self.velocityProfileID = domain.velocityProfileID
        self.sortOrder = domain.sortOrder
        self.createdAt = createdAt
    }

    /// Converts back to the domain model.
    public func toDomain() -> TrackedApp {
        let label = AppLabel(rawValue: userLabel) ?? .otherText
        return TrackedApp(
            tokenHash: tokenHash,
            userLabel: label,
            velocityProfileID: velocityProfileID,
            sortOrder: sortOrder
        )
    }
}
