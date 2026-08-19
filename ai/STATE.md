# STATE — Scrollometer

Updated: 2026-08-18 (session 3: Mac blocker ELIMINATED — GitHub Actions CI pipeline, repo pushed public to github.com/pmartin1915/scrollometer)

## Session 3: the no-Mac CI path (plan of record: `C:\Users\perry\.claude\plans\i-am-a-27-cosmic-cake.md`)

- **The "one Mac session" blocker is gone.** wilderness + burn-wizard proved bot-only iOS build/sign/upload on macOS runners; adapted here. Three phases:
  - **Phase A (LIVE)**: `ios-compile.yml` — unsigned build of all 4 targets + ScrollStore tests on `macos-26`. This is the compile-verification loop for every API flagged below; iterate red→fix→dispatch until green.
  - **Phase B (next)**: dev-signed IPA from CI → sideload from Windows via pymobiledevice3 (NOT Sideloadly — it re-signs and strips Family Controls) → M1 device tests. **Not gated on Apple's grant** (Family Controls Development needs none). Needs: openssl CSR on Windows, dev cert + iPhone UDID + 4 dev profiles via portal browser session, secrets per `docs/ci-build.md`.
  - **Phase C (gated on entitlement grant)**: distribution signing + altool → TestFlight. Profiles must be created AFTER enabling the granted capability. Needs Perry to locate the wilderness distribution cert PEM/key + ASC .p8 originals (secrets can't be copied between GitHub repos).
- **Hosting decided**: public repo `pmartin1915/scrollometer` (free macOS minutes) → flip private once Phase C is green. Perry approved 2026-08-18.
- project.yml now carries `CODE_SIGN_STYLE: Manual`, `DEVELOPMENT_TEAM`, per-target `PROVISIONING_PROFILE_SPECIFIER: $(ODO_PROFILE_*)` (names injected at archive time), and a shared scheme. GRDB floor bumped to 6.16 (`.wal` requirement). Runbook: `docs/ci-build.md`.
- **Email discrepancy to resolve**: entitlement watch says pmartin1912@gmail.com; session identity is pmartin1913@gmail.com. Confirm which inbox is the Apple ID before the grant email is missed.

## Session 2 additions

- **Apple Developer portal (Claude-driven browser, Perry authenticated/approved)**: App Group `group.com.martinapps.scrolldistance` + all 4 App IDs registered. Capabilities: app/monitor/report have App Groups + Family Controls (Development) + Family Controls App and Website Usage; widgets has App Groups only.
- **Family Controls distribution entitlement request SUBMITTED 2026-08-18** — team-level acknowledgment form (new-style, no justification essay). Watch pmartin1912@gmail.com. On grant: mac-setup-checklist "After granted" section.
- **WP4 (ScrollStore) merged** — Kimi-implemented, reviewed. Watch item for first Mac build: `Configuration.journalMode = .wal` requires GRDB ≥6.16 (Package.swift says `from: 6.0.0`, resolves latest 6.x — fine unless pinned down).
- **Kimi lane workaround**: launch `kimi-exec.sh --implement ... &` detached inside a single Bash call (wrapper keeps its own --timeout); poll `.orchestrate/logs/*-implement.log` tail for `TurnEnd()`. Direct run_in_background of the wrapper gets killed by the harness and orphans the CLI (see memory note).
- **WP5+WP6 MERGED (631e3d3)** — Kimi-implemented, reviewed closest on the extension: imports clean (no GRDB/SwiftUI in MonitorExtension), fire-time day-key derivation, idempotent high-water writes, 8-day prune, `lastFireAt` liveness. Kimi self-flagged API points for the first Mac build (its handoff note, tail of `.orchestrate/logs/20260818T212218Z-implement.log`): `Label(token)` init form, `DeviceActivityEvent(applications:threshold:)`, `@State`+`@Observable` wiring — hand-check on first compile.
- **WP7+WP8 MERGED (1c69ee7)** — Today dashboard (odometer/landmark/streak/per-app bars), History (Swift Charts, DayKey gets a retroactive `Plottable` conformance in the App layer — move into ScrollCore if it ever conflicts), Methodology view (derives numbers from the bundled table at runtime), weekly recap (sealed Mon–Sun weeks only), ImageRenderer share cards (1080×1920 + 1080×1080, minimumScaleFactor), live widget (read-only DB, refuses to create/migrate from the widget process, 30-min timeline). Kimi's compile-uncertain flags for first Mac build: `Transferable`/`DataRepresentation` strict-concurrency, ImageRenderer sizing via inner `.frame`.
- **WP1–WP8 are now ALL merged.** Remaining: WP9 (nudges/goal + real Settings + methodology polish — gate on M1 results), WP10 (StoreKit paywall + submission kit — gate on entitlement grant + name check).
- **M1 on-device verification is now UNBLOCKED** — the full pipeline (onboarding → monitor extension → bridge → debug screen) exists. Perry's Mac session: `docs/mac-setup-checklist.md` steps 4–8 (portal steps 1–3 are DONE via browser session), then `docs/on-device-test-script.md` sections A–C.
- **Lesson (git)**: piping `git merge` output to `tail` swallowed a merge failure and let `git worktree remove --force` run — recovered via dangling-commit SHA merge. Don't chain destructive cleanup behind a pipe; check merge success directly.

## Done

- **Plan of record**: `C:\Users\perry\.claude\plans\i-am-a-27-abstract-wall.md` (research-backed; WP1–WP10, M0–M4). Decisions locked: name Scrollometer, stats+nudges scope, free core + $9.99/yr premium, v2 social deferred to `ai/IDEAS.md`.
- **WP1 (scaffold)**: XcodeGen `project.yml` (4 targets, entitlements wired via INFOPLIST_FILE — do NOT switch to XcodeGen's `info:` key, it regenerates/clobbers plists), SPM packages, Linux CI workflow. Implemented by Kimi via /orchestrate; review fixes: real `DeviceActivityReportScene` conformance, ExtensionKit target type + `EXAppExtensionAttributes` for ReportExtension.
- **WP2+WP3 (ScrollCore domain logic)**: conversion engine + velocity/device/landmark tables + TokenHasher + high-water accumulator + threshold ladder + reconciler. **34 tests green** via `docker run … swift:5.10 swift test` (repeat locally: `MSYS_NO_PATHCONV=1 docker run --rm -v "C:/Users/perry/DevProjects/swipe_length/Packages/ScrollCore:/src" -w /src swift:5.10 swift test`). Authored by Claude directly (Kimi lane broke mid-session — see Notes).
- Calibration note: 60 min TikTok on a 6.1" phone ≈ **197 ft** (7.1 screens/min × 5.56 in). The plan's earlier "340–420 ft" AC was bad arithmetic; 197 ft/hr is coherent with the NYU ~300 ft/day average-user aggregate. Methodology page copy already matches.

## Next (in order)

1. **Phase A green**: iterate `ios-compile.yml` until all 4 targets compile and ScrollStore tests pass; check off the unverified-API list as items compile. Commit `Packages/ScrollStore/Package.resolved` from the CI artifact once green.
2. **Phase B**: Windows CSR → portal session (dev cert, iPhone UDID, 4 dev profiles) → secrets → `ios-build.yml` dev archive → pymobiledevice3 install → `docs/on-device-test-script.md` A–C = **M1 gate**.
3. **WP9** (nudges/goal/settings) once M1 numbers are in.
4. **Phase C + WP10** (paywall/submission) once the entitlement grant lands. Name-check "Scrollometer" via the App Store Connect app-record creation (can happen any time).

## Notes / decisions this session

- **Kimi background-run hazard**: `kimi-exec.sh --implement` launched via a backgrounded shell got its wrapper killed twice (harness interaction), which ORPHANS the kimi CLI process — it keeps running/writing with no timeout and locks the worktree. If it recurs: check `Get-Process kimi` (lowercase = CLI), kill orphans, reset worktree before any re-run. Consider running implement legs attended/foreground or via a scheduler that owns the process tree.
- Executor pipeline remains the plan for WP4+ once the lane is stable; WP2/3 being Claude-authored means a decorrelated cross-model audit of `Packages/ScrollCore` is still owed (Kimi audit lane per orchestrate skill) before M2 is declared done.
- `.claude/` and `.orchestrate/` are gitignored. No git remote configured yet — decide hosting (GitHub private?) at M0.
