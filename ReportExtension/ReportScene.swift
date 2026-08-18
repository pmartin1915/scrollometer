import DeviceActivity
import SwiftUI

@main
struct ReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { _ in
            TotalActivityView()
        }
    }
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (String) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        // WP-M4: aggregate data into a display string. Placeholder until the compare screen ships.
        ""
    }
}

struct TotalActivityView: View {
    var body: some View {
        Text("—")
    }
}
