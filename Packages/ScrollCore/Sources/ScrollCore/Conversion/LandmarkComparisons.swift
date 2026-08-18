import Foundation

/// Picks a shareable landmark comparison for a distance
/// ("7.6 Statues of Liberty").
public enum LandmarkComparisons {
    public struct Comparison: Equatable, Sendable {
        public let landmarkName: String   // singular or plural, matched to the multiplier
        public let multiplier: Double     // rounded to 1 decimal
    }

    struct Landmark: Codable {
        let id: String
        let name: String
        let plural: String
        let feet: Double
    }

    struct LandmarkFile: Codable {
        let schemaVersion: Int
        let landmarks: [Landmark]   // must be sorted ascending by feet
    }

    static func loadLandmarks() throws -> [Landmark] {
        try ResourceLoader.load(LandmarkFile.self, resource: "landmarks_v1").landmarks
    }

    /// The largest landmark the distance covers at least once, with the
    /// multiplier rounded to one decimal. Returns nil below the smallest
    /// landmark (no "0.3 football fields" shame math).
    public static func best(forFeet feet: Double) -> Comparison? {
        guard let landmarks = try? loadLandmarks() else { return nil }
        for landmark in landmarks.reversed() {
            let multiplier = feet / landmark.feet
            if multiplier >= 1.0 {
                let rounded = (multiplier * 10).rounded() / 10
                let name = rounded == 1.0 ? landmark.name : landmark.plural
                return Comparison(landmarkName: name, multiplier: rounded)
            }
        }
        return nil
    }
}
