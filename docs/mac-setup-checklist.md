# Mac setup checklist (one-time + per-session)

Everything scriptable lives in the repo (`project.yml`, entitlements plists, SPM packages). These are the steps that must happen on the Mac / in the Apple Developer portal.

## One-time (M0 session)

1. **Developer portal — Identifiers**: create 4 App IDs:
   - `com.martinapps.scrolldistance` (App) — capabilities: App Groups, Family Controls
   - `com.martinapps.scrolldistance.monitor` — App Groups, Family Controls
   - `com.martinapps.scrolldistance.report` — App Groups, Family Controls
   - `com.martinapps.scrolldistance.widgets` — App Groups only
2. **App Group**: create `group.com.martinapps.scrolldistance`; attach to all four App IDs.
3. **File the distribution entitlement request** (see `entitlement-request.md`) — do this the same day; it's the critical path. Development entitlement needs no request.
4. **Local tooling**: `brew install xcodegen` (and optionally `brew install fastlane` for M4).
5. **Generate + open**: `xcodegen generate && xed .`
6. **Signing & Capabilities** (each target): select team; confirm App Group + Family Controls (development) appear from the committed `.entitlements` files. If Xcode complains, toggle the capability on once so it registers with the profile.
7. **Build to a physical device** (Simulator is useless for Screen Time). Confirm the FamilyControls authorization prompt appears.
8. **Verify the ReportExtension target shape**: it was authored as an ExtensionKit extension (`type: extensionkit-extension`, `EXAppExtensionAttributes`/`EXExtensionPointIdentifier` in its Info.plist) — the modern form for DeviceActivityReport. If it fails to build or load, create a throwaway "Device Activity Report Extension" from Xcode's template and diff its Info.plist/target settings against ours; correct ours to match and update `project.yml` accordingly.

## Per-session (after pulling changes authored on Windows)

1. `xcodegen generate` (regenerates the project if `project.yml` changed)
2. Build to device; run whatever step of `on-device-test-script.md` the current milestone calls for.
3. If anything needed manual Xcode fiddling, record it HERE so the checklist stays current.

## After the distribution entitlement is granted

1. Developer portal: confirm "Family Controls (Distribution)" appears under each App ID's Additional Capabilities; enable it.
2. Regenerate distribution provisioning profiles; rebuild; archive a TestFlight build to confirm signing passes.
3. Update the log in `entitlement-request.md`.
