import Foundation

/// Shared text formatting for estimated scroll distances.
///
/// Keeps the "at least / estimated" framing consistent across Today, History,
/// the widget, and share cards.
enum DistanceFormatter {
    /// "~1,234 ft" or "~1.23 mi", switching at half a mile.
    static func estimated(_ feet: Double) -> String {
        if feet < 0.5 * 5280 {
            return "~\(Int(feet.rounded())) ft"
        } else {
            return String(format: "~%.2f mi", feet / 5280.0)
        }
    }

    /// Compact widget/list form: "312 ft" / "1.2 mi".
    static func compact(_ feet: Double) -> String {
        if feet < 5280 {
            return "\(Int(feet.rounded())) ft"
        } else {
            return String(format: "%.1f mi", feet / 5280.0)
        }
    }
}
