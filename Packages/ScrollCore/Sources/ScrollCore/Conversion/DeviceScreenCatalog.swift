import Foundation

/// Physical screen description used to convert screen-heights to distance.
public struct DeviceScreen: Equatable, Sendable {
    public let physicalHeightInches: Double
    public let confidence: DistanceResult.Confidence

    public init(physicalHeightInches: Double, confidence: DistanceResult.Confidence) {
        self.physicalHeightInches = physicalHeightInches
        self.confidence = confidence
    }
}

/// Model-identifier → physical screen lookup. The app layer supplies the
/// identifier (utsname.machine) and, for the fallback, UIScreen's native
/// pixel height — ScrollCore stays UIKit-free.
public enum DeviceScreenCatalog {
    struct Entry: Codable {
        let identifier: String
        let nativePixelHeight: Int
        let ppi: Int
        let physicalHeightInches: Double
    }

    struct Catalog: Codable {
        let schemaVersion: Int
        let devices: [Entry]
    }

    static func loadCatalog() throws -> Catalog {
        try ResourceLoader.load(Catalog.self, resource: "device_screens_v1")
    }

    /// Exact-match lookup (e.g. "iPhone15,2"); no normalization.
    public static func lookup(modelIdentifier: String) -> DeviceScreen? {
        guard let catalog = try? loadCatalog(),
              let entry = catalog.devices.first(where: { $0.identifier == modelIdentifier })
        else { return nil }
        return DeviceScreen(physicalHeightInches: entry.physicalHeightInches, confidence: .measured)
    }

    /// Fallback for unknown identifiers: assume a modern ~460 ppi panel.
    public static func fallback(nativePixelHeight: Int) -> DeviceScreen {
        DeviceScreen(
            physicalHeightInches: Double(nativePixelHeight) / 460.0,
            confidence: .approximate
        )
    }
}
