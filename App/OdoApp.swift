import SwiftUI

@main
struct OdoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

@MainActor
private struct RootView: View {
    @AppStorage("meta.onboardingComplete", store: AppGroup.defaults)
    private var onboardingComplete = false

    @State private var todayModel = try! TodayModel(
        database: AppDatabase(url: AppGroup.databaseURL)
    )

    var body: some View {
        Group {
            if onboardingComplete {
                TabView {
                    TodayDashboardView(model: todayModel)
                        .tabItem {
                            Label("Today", systemImage: "gauge")
                        }

                    HistoryView()
                        .tabItem {
                            Label("History", systemImage: "chart.bar")
                        }

                    WeeklyRecapView()
                        .tabItem {
                            Label("Recap", systemImage: "sparkles")
                        }
                }
            } else {
                OnboardingFlowView(
                    selectionStore: SelectionStore(
                        database: try! AppDatabase(url: AppGroup.databaseURL)
                    )
                )
            }
        }
    }
}
