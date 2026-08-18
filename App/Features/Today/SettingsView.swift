import Observation
import SwiftUI

/// Placeholder settings screen. The only real action is reaching the legacy
/// debug view, which still shares `TodayModel` so drain logic is not duplicated.
struct SettingsView: View {
    @Bindable var model: TodayModel

    var body: some View {
        List {
            Section("Diagnostics") {
                NavigationLink("Debug") {
                    TodayDebugView(model: model)
                }
            }
        }
        .navigationTitle("Settings")
    }
}
