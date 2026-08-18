import FamilyControls
import Foundation
import ScrollCore
import ScrollStore

/// Persists the user's FamilyActivitySelection and labeled tracked apps.
public final class SelectionStore {
    private let defaults: UserDefaults
    private let queries: StoreQueries
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = AppGroup.defaults, database: AppDatabase) {
        self.defaults = defaults
        self.queries = StoreQueries(database: database)
    }

    private var selectionKey: String { "selection.v1" }

    /// Loads the previously saved selection, or an empty selection.
    public func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: selectionKey),
              let selection = try? decoder.decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    /// Saves the raw selection to App Group defaults.
    public func saveSelection(_ selection: FamilyActivitySelection) throws {
        let data = try encoder.encode(selection)
        defaults.set(data, forKey: selectionKey)
    }

    /// Persists each labeled token as a tracked app row in the database.
    public func saveLabeledApps(
        selection: FamilyActivitySelection,
        labels: [String: AppLabel],
        now: Date
    ) throws {
        var sortOrder = 0
        for token in selection.applicationTokens {
            let tokenData = try encoder.encode(token)
            let hash = TokenHasher.hash(encodedToken: tokenData)
            guard let label = labels[hash] else { continue }

            let app = TrackedApp(
                tokenHash: hash,
                userLabel: label,
                sortOrder: sortOrder
            )
            try queries.upsertTrackedApp(app, tokenData: tokenData, now: now)
            sortOrder += 1
        }
    }
}
