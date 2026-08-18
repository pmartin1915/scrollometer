# WP1 — Repo scaffold: XcodeGen project, targets, entitlements, CI

## Goal
A complete, XcodeGen-generatable Xcode project definition with 4 targets, App Group + Family Controls entitlements wired, two SPM packages with compilable skeletons, and a Linux CI workflow running `swift test` on ScrollCore. Everything authored as plain text (no `.xcodeproj` committed).

## Deliverables

### 1. `project.yml` (XcodeGen)
- Project name: `Scrollometer`; `options.bundleIdPrefix: com.martinapps`; deployment target iOS 17.0; Swift 5.10.
- Targets:
  - **Scrollometer** (app): sources `App/`, entitlements `App/Odo.entitlements`, Info.plist `App/Info.plist`, depends on packages `ScrollCore` + `ScrollStore`, embeds the 3 extensions.
  - **MonitorExtension** (app-extension, point `NSExtensionPointIdentifier: com.apple.deviceactivity.monitor-extension`): sources `MonitorExtension/`, depends on `ScrollCore` ONLY (never ScrollStore/GRDB — extension memory budget).
  - **ReportExtension** (app-extension, `com.apple.deviceactivity.report-extension`): sources `ReportExtension/`, depends on `ScrollCore` only.
  - **OdoWidgets** (app-extension, `com.apple.widgetkit-extension`): sources `OdoWidgets/`, depends on `ScrollCore` + `ScrollStore`.
- Bundle IDs exactly: `com.martinapps.scrolldistance`, `.monitor`, `.report`, `.widgets` suffixed forms as in README.
- Local SPM packages referenced by path: `Packages/ScrollCore`, `Packages/ScrollStore`.

### 2. Entitlements plists (4 files)
- App/Monitor/Report: `com.apple.developer.family-controls` = true AND `com.apple.security.application-groups` = [`group.com.martinapps.scrolldistance`].
- Widgets: App Group only.

### 3. Info.plists
Minimal valid plists per target type. Extensions need correct `NSExtension` dictionaries (DeviceActivityMonitor extensions use principal class `ActivityMonitor` subclassing `DeviceActivityMonitor`; Report uses a `DeviceActivityReportScene` SwiftUI entry; widget uses `@main` WidgetBundle — follow current Apple templates).

### 4. Compilable stubs
- `App/OdoApp.swift`: `@main` SwiftUI App showing a placeholder Today screen ("Scrollometer — tracking not configured").
- `MonitorExtension/ActivityMonitor.swift`: `DeviceActivityMonitor` subclass with empty overrides (`intervalDidStart`, `intervalDidEnd`, `eventDidReachThreshold`, `intervalWillEndWarning`) and `// WP5` markers.
- `ReportExtension/ReportScene.swift`: minimal `DeviceActivityReportExtension` scene stub.
- `OdoWidgets/DailyDistanceWidget.swift`: minimal static widget showing "— ft".
- `Packages/ScrollCore/Package.swift`: swift-tools 5.10, platforms `[.iOS(.v17), .macOS(.v14)]`, NO iOS-only frameworks, dependency on `swift-crypto` (for portable SHA256), resources folder processed. One placeholder type + one placeholder test so `swift test` runs green.
- `Packages/ScrollStore/Package.swift`: depends on ScrollCore + GRDB (`https://github.com/groue/GRDB.swift`, from: "6.0.0"). Placeholder `AppDatabase` type. (Its tests are Mac-only; keep the package compiling but do not add Linux CI for it.)

### 5. CI: `.github/workflows/scrollcore-tests.yml`
- Trigger: push + PR on any branch touching `Packages/ScrollCore/**` or the workflow file.
- Job: `ubuntu-latest`, official Swift 5.10+ container or swift-actions/setup-swift, `cd Packages/ScrollCore && swift test`.

### 6. `docs/` untouched; do not modify README except to fix factual drift you introduce.

## Acceptance criteria
- `xcodegen generate` on a machine with XcodeGen succeeds (executor: validate `project.yml` against XcodeGen schema to best ability without a Mac; YAML must lint).
- `swift test` in `Packages/ScrollCore` passes on Linux/Windows toolchain.
- All 4 entitlements files exact-match the bundle-ID/App-Group table above (reviewer will diff character-by-character).
- No `.xcodeproj`, `DerivedData`, or `Package.resolved` committed.
- MonitorExtension has zero dependency on ScrollStore/GRDB anywhere in project.yml.
