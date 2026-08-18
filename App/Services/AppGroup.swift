import Foundation

/// Shared App Group container used by the main app, widgets, and extensions.
public enum AppGroup {
    public static let identifier = "group.com.martinapps.scrolldistance"

    /// URL of the GRDB database inside the shared App Group container.
    public static var databaseURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)!
            .appendingPathComponent("odo.sqlite")
    }

    /// Shared `UserDefaults` suite written by the app and the monitor extension.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier)!
    }
}
