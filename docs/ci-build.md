# CI build runbook — no Mac required

Every Xcode-dependent step (compile, sign, archive, TestFlight upload) runs on
GitHub Actions macOS runners. Pattern proven in wilderness and burn-wizard,
where the entire iOS pipeline ran bot-only; adapted here for a native Swift
multi-target app with entitlements.

Repo: https://github.com/pmartin1915/scrollometer
Visibility: **public while the pipeline stabilizes** (macOS minutes free on
public repos; 10x-metered on private). Flip to private in Settings once Phase C
is green. Note: forks made while public stay public after the flip.

## The three run modes

| Mode | Workflow | Trigger | Signing | Output |
|---|---|---|---|---|
| Compile check | `ios-compile.yml` | `gh workflow run "iOS Compile Check"` | none (`CODE_SIGNING_ALLOWED=NO`) | pass/fail + ScrollStore test results |
| Dev device build | `ios-build.yml`, method=`debugging` | `gh workflow run "iOS Build" -f method=debugging` | Apple Development cert + 4 dev profiles (iPhone UDID in each) | IPA artifact → sideload from Windows |
| TestFlight | `ios-build.yml`, method=`app-store-connect` | tag push `v*.*.*` (or dispatch) | Apple Distribution cert + 4 App Store profiles | upload to App Store Connect |

Dev builds carry Family Controls with **no Apple grant** (development capability
is free). TestFlight builds are distribution-signed and are **gated on the
Family Controls distribution entitlement grant** (requested 2026-08-18).

## Signing model

- `project.yml` sets `CODE_SIGN_STYLE: Manual`, `DEVELOPMENT_TEAM: NN8F5WX25R`,
  and per-target `PROVISIONING_PROFILE_SPECIFIER: $(ODO_PROFILE_*)`.
- The workflow passes `ODO_PROFILE_APP/_MONITOR/_REPORT/_WIDGETS` (profile
  *names*) on the `xcodebuild archive` command line, so one project definition
  serves all three modes. If `$(VAR)` expansion ever misbehaves, fall back to
  hardcoding dev names under a Debug config block and dist names under Release.
- ExportOptions.plist is generated at run time with a **4-entry
  provisioningProfiles dict** (one per bundle ID — every embedded target needs
  its entry). Dev export method is `debugging` (Xcode 15.4+ name).

## Secrets

Set from Windows: `openssl base64 -A -in <file> | gh secret set <NAME> -R pmartin1915/scrollometer`

| Secret | Value | Phase |
|---|---|---|
| `APPLE_DEV_CERTIFICATE_PEM` | base64 PEM of the Apple Development cert (`openssl x509 -inform DER -in development.cer`) | B |
| `APPLE_DEV_PRIVATE_KEY` | base64 of the CSR's RSA-2048 private key PEM | B |
| `APPLE_CERTIFICATE_PASSWORD` | arbitrary p12 transit password | B |
| `PROVISION_DEV_APP/_MONITOR/_REPORT/_WIDGETS` | base64 of the 4 iOS App Development `.mobileprovision` files | B |
| `APPLE_CERTIFICATE_PEM` / `APPLE_PRIVATE_KEY` | base64 PEMs of the team Apple Distribution cert (same files that seeded wilderness — GitHub can't copy secrets between repos) | C |
| `PROVISION_DIST_APP/_MONITOR/_REPORT/_WIDGETS` | base64 of the 4 App Store profiles (create AFTER the entitlement grant) | C |
| `APP_STORE_CONNECT_API_KEY` | plain text of the `.p8` (NOT base64) | C |
| `APP_STORE_CONNECT_API_KEY_ID` | `TM3T3B7QBF` | C |
| `APP_STORE_CONNECT_API_ISSUER_ID` | `65fd510f-6e05-43bb-a4c7-3e6a09854727` | C |

## Profile creation / regeneration (portal)

Dev (Phase B): Certificates → Apple Development (upload a CSR generated on
Windows with openssl, RSA-2048). Devices → register the iPhone UDID. Profiles →
4× "iOS App Development", one per App ID, selecting the dev cert + the iPhone:
`Scrollometer App Dev`, `Scrollometer Monitor Dev`, `Scrollometer Report Dev`,
`Scrollometer Widgets Dev`.

Dist (Phase C, AFTER the grant email): enable Family Controls (Distribution) on
the app/monitor/report App IDs FIRST, then create 4 "App Store" profiles —
profiles embed entitlements at creation time, so ordering matters. Names must
match `ios-build.yml` exactly: `Scrollometer App Store`,
`Scrollometer Monitor App Store`, `Scrollometer Report App Store`,
`Scrollometer Widgets App Store`.

**Pre-flight before burning CI minutes** — verify entitlements inside each
downloaded profile on Windows:

    openssl smime -verify -noverify -inform der -in <profile>.mobileprovision

Confirm `com.apple.developer.family-controls` and
`group.com.martinapps.scrolldistance` appear in the Entitlements dict of the
app/monitor/report profiles. Missing ⇒ fix the App ID capability in the portal
and regenerate; do not dispatch the build.

## Windows sideload (dev builds)

1. `pip install pymobiledevice3`; connect iPhone via USB; tap Trust.
2. `gh run download <run-id> -n scrollometer-ipa` (or grab from the run page).
3. `pymobiledevice3 apps install Scrollometer.ipa` — installs **as-signed**.
   Never use Sideloadly: it re-signs, which strips the Family Controls
   entitlement.
4. Enable Developer Mode: Settings → Privacy & Security → Developer Mode
   (or `pymobiledevice3 amfi enable-developer-mode`); device reboots.
5. Launch; trust the developer profile under Settings → General → VPN & Device
   Management if prompted. Then run `on-device-test-script.md`.

## Troubleshooting

- **"MAC verification failed" importing the p12**: the workflow must call
  `/usr/bin/openssl` (Apple LibreSSL). Homebrew OpenSSL 3 writes a PBMAC1 MAC
  that `security import` rejects. Never "fix" this with a PATH openssl.
- **Apple 409 on upload / wrong SDK**: archive must be built with the iOS 26
  SDK. The workflow asserts `DTSDKName` in the archive; if it trips, the runner
  image's default Xcode drifted — pin with `sudo xcode-select -s`.
- **Export fails on a profile mismatch**: check all 4 entries in the
  provisioningProfiles dict and that each profile secret decodes to the profile
  whose name the dict references.
- **codesign hangs**: the keychain step must run
  `security set-key-partition-list -S apple-tool:,apple:`.
- **ReportExtension archive/load problems**: it's an ExtensionKit extension
  (`Extensions/*.appex` in the bundle, not `PlugIns/`); if the shape is wrong,
  diff against an Xcode "Device Activity Report Extension" template via CI
  iterations (old checklist step 8).
