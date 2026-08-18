import Foundation

/// A calendar day ("yyyy-MM-dd") anchored to a specific time zone.
/// Comparable chronologically (ISO-8601 rawValue ordering is chronological).
public struct DayKey: Hashable, Codable, Comparable, Sendable {
    public let rawValue: String

    /// The day containing `date` in `timeZone`.
    public init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.rawValue = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Fails unless `rawValue` is a valid "yyyy-MM-dd" calendar date.
    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        guard comps.isValidDate(in: calendar) else { return nil }
        self.rawValue = String(format: "%04d-%02d-%02d", y, m, d)
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid DayKey: \(raw)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The first instant of the NEXT calendar day in the named time zone.
    /// Invalid time-zone identifiers are treated as UTC.
    public func endOfDay(timeZoneID: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "UTC")!
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        var comps = DateComponents()
        comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startOfDay = calendar.date(from: comps)!
        return calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    }
}
