import Foundation

/// Ladder shape for DeviceActivityEvent minute thresholds.
public struct LadderConfig: Codable, Equatable, Sendable {
    public var fineStepMinutes: Int
    public var fineUpTo: Int
    public var mediumStepMinutes: Int
    public var mediumUpTo: Int
    public var coarseStepMinutes: Int
    public var coarseUpTo: Int

    public init(fineStepMinutes: Int, fineUpTo: Int, mediumStepMinutes: Int, mediumUpTo: Int, coarseStepMinutes: Int, coarseUpTo: Int) {
        self.fineStepMinutes = fineStepMinutes
        self.fineUpTo = fineUpTo
        self.mediumStepMinutes = mediumStepMinutes
        self.mediumUpTo = mediumUpTo
        self.coarseStepMinutes = coarseStepMinutes
        self.coarseUpTo = coarseUpTo
    }

    /// 1-min steps to 60, 5-min to 180, 15-min to 480 → 104 steps/app.
    public static let standard = LadderConfig(fineStepMinutes: 1, fineUpTo: 60, mediumStepMinutes: 5, mediumUpTo: 180, coarseStepMinutes: 15, coarseUpTo: 480)

    /// If the standard ladder proves unreliable on-device (M1 test):
    /// 2-min steps to 60, 10-min to 180, 15-min to 480 → 62 steps/app.
    public static let fallback = LadderConfig(fineStepMinutes: 2, fineUpTo: 60, mediumStepMinutes: 10, mediumUpTo: 180, coarseStepMinutes: 15, coarseUpTo: 480)
}

/// Generates threshold steps and encodes/decodes event names.
/// Event name format: "a:<16-hex tokenHash>:m:<minutes>".
public enum ThresholdLadder {
    /// Strictly ascending minute thresholds, no duplicates.
    public static func steps(config: LadderConfig) -> [Int] {
        var result: [Int] = []
        var m = config.fineStepMinutes
        while m <= config.fineUpTo {
            result.append(m)
            m += config.fineStepMinutes
        }
        m = config.fineUpTo + config.mediumStepMinutes
        while m <= config.mediumUpTo {
            result.append(m)
            m += config.mediumStepMinutes
        }
        m = config.mediumUpTo + config.coarseStepMinutes
        while m <= config.coarseUpTo {
            result.append(m)
            m += config.coarseStepMinutes
        }
        return result
    }

    public static func eventCount(config: LadderConfig, appCount: Int) -> Int {
        steps(config: config).count * appCount
    }

    public static func eventName(tokenHash: String, minutes: Int) -> String {
        "a:\(tokenHash):m:\(minutes)"
    }

    /// Strict parse; malformed names return nil.
    public static func parse(eventName: String) -> (tokenHash: String, minutes: Int)? {
        let parts = eventName.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == "a", parts[2] == "m" else { return nil }
        let hash = String(parts[1])
        guard hash.count == 16, hash.allSatisfy({ $0.isHexDigit && (!$0.isLetter || $0.isLowercase) }) else { return nil }
        guard let minutes = Int(parts[3]), minutes > 0, !parts[3].hasPrefix("+") else { return nil }
        return (hash, minutes)
    }
}
