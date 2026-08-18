import Foundation

/// Minimal App Group constants for the monitor extension.
/// The extension must not import ScrollStore, so this local copy keeps it self-contained.
enum AppGroup {
    static let identifier = "group.com.martinapps.scrolldistance"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier)!
    }
}
