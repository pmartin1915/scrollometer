import Foundation
import GRDB

/// GRDB schema migrations for the Scrollometer persistence layer.
public enum Migrations {
    /// The migrator that creates the ScrollStore schema.
    public static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE tracked_app (
                  token_hash TEXT PRIMARY KEY,
                  token_data BLOB NOT NULL,
                  user_label TEXT NOT NULL,
                  velocity_profile_id TEXT NOT NULL,
                  sort_order INTEGER NOT NULL,
                  created_at DATETIME NOT NULL
                );
                CREATE TABLE daily_usage (
                  day_key TEXT NOT NULL,
                  token_hash TEXT NOT NULL,
                  minutes INTEGER NOT NULL,
                  tz_identifier TEXT NOT NULL,
                  source TEXT NOT NULL DEFAULT 'threshold',
                  updated_at DATETIME NOT NULL,
                  PRIMARY KEY (day_key, token_hash)
                );
                CREATE TABLE daily_distance_cache (
                  day_key TEXT NOT NULL,
                  token_hash TEXT NOT NULL,
                  feet REAL NOT NULL,
                  velocity_table_version INTEGER NOT NULL,
                  PRIMARY KEY (day_key, token_hash)
                );
                CREATE TABLE app_meta (
                  key TEXT PRIMARY KEY,
                  value TEXT NOT NULL
                );
                """)
        }

        return migrator
    }
}
