import Foundation

/// Minimal App Group constants for the widget extension.
/// The widget must not import ScrollStore, so this local copy keeps it self-contained.
enum AppGroup {
    static let identifier = "group.com.martinapps.scrolldistance"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier)!
    }

    static var databaseURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)!
            .appendingPathComponent("odo.sqlite")
    }
}
