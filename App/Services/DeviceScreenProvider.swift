import Darwin
import Foundation
import ScrollCore
import UIKit

/// Resolves the current device's physical screen description for the conversion engine.
public enum DeviceScreenProvider {
    @MainActor
    public static func screenForCurrentDevice() -> DeviceScreen {
        if let screen = DeviceScreenCatalog.lookup(modelIdentifier: machineIdentifier()) {
            return screen
        }
        return DeviceScreenCatalog.fallback(
            nativePixelHeight: Int(UIScreen.main.nativeBounds.height)
        )
    }

    /// e.g. "iPhone15,2" via `uname(3)`.
    private static func machineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { boundPointer in
                String(cString: boundPointer)
            }
        }
    }
}
