import DeviceActivity
import SwiftUI

@main
struct ReportScene: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DeviceActivityReportScene { _ in
            Text("—")
        }
    }
}
