import SwiftUI

@main
struct OdoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    @AppStorage("meta.onboardingComplete", store: AppGroup.defaults)
    private var onboardingComplete = false

    @State private var selectionStore = SelectionStore(
        database: try! AppDatabase(url: AppGroup.databaseURL)
    )

    var body: some View {
        Group {
            if onboardingComplete {
                TodayDebugView()
            } else {
                OnboardingFlowView(selectionStore: selectionStore)
            }
        }
    }
}
