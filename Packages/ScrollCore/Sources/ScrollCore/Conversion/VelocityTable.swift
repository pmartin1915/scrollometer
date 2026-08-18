import Foundation

/// One app-category scroll-velocity profile.
public struct VelocityProfile: Codable, Equatable, Sendable {
    public let id: String
    public let screenHeightsPerMinute: Double
    /// Human-readable, citable justification — surfaced on the methodology page.
    public let basis: String

    public init(id: String, screenHeightsPerMinute: Double, basis: String) {
        self.id = id
        self.screenHeightsPerMinute = screenHeightsPerMinute
        self.basis = basis
    }
}

/// Versioned table of velocity profiles. Bundled with the app; optionally
/// replaced by a remote table via `accept(remote:)` version gating.
public struct VelocityTable: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let version: Int
    public let profiles: [VelocityProfile]

    public init(schemaVersion: Int, version: Int, profiles: [VelocityProfile]) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.profiles = profiles
    }

    public func profile(id: String) -> VelocityProfile? {
        profiles.first { $0.id == id }
    }

    /// Returns `remote` only if it is a strict version upgrade with a matching
    /// schema; otherwise returns `self`. Same-version remotes are rejected
    /// regardless of content.
    public func accept(remote: VelocityTable) -> VelocityTable {
        guard remote.schemaVersion == schemaVersion, remote.version > version else { return self }
        return remote
    }

    /// Decodes the table bundled in ScrollCore's resources.
    public static func bundled() throws -> VelocityTable {
        try ResourceLoader.load(VelocityTable.self, resource: "velocity_table_v1")
    }
}

/// Shared JSON resource loading; throws on missing/malformed resources.
enum ResourceLoader {
    struct MissingResource: Error { let name: String }

    static func load<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json") else {
            throw MissingResource(name: resource)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
