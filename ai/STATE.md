# STATE — Scrollometer

Updated: 2026-08-18 (session 1: planning + WP1–WP3)

## Done

- **Plan of record**: `C:\Users\perry\.claude\plans\i-am-a-27-abstract-wall.md` (research-backed; WP1–WP10, M0–M4). Decisions locked: name Scrollometer, stats+nudges scope, free core + $9.99/yr premium, v2 social deferred to `ai/IDEAS.md`.
- **WP1 (scaffold)**: XcodeGen `project.yml` (4 targets, entitlements wired via INFOPLIST_FILE — do NOT switch to XcodeGen's `info:` key, it regenerates/clobbers plists), SPM packages, Linux CI workflow. Implemented by Kimi via /orchestrate; review fixes: real `DeviceActivityReportScene` conformance, ExtensionKit target type + `EXAppExtensionAttributes` for ReportExtension.
- **WP2+WP3 (ScrollCore domain logic)**: conversion engine + velocity/device/landmark tables + TokenHasher + high-water accumulator + threshold ladder + reconciler. **34 tests green** via `docker run … swift:5.10 swift test` (repeat locally: `MSYS_NO_PATHCONV=1 docker run --rm -v "C:/Users/perry/DevProjects/swipe_length/Packages/ScrollCore:/src" -w /src swift:5.10 swift test`). Authored by Claude directly (Kimi lane broke mid-session — see Notes).
- Calibration note: 60 min TikTok on a 6.1" phone ≈ **197 ft** (7.1 screens/min × 5.56 in). The plan's earlier "340–420 ft" AC was bad arithmetic; 197 ft/hr is coherent with the NYU ~300 ft/day average-user aggregate. Methodology page copy already matches.

## Next (in order)

1. **OPERATOR (critical path): M0 Mac session** — `docs/mac-setup-checklist.md` steps 1–8, and **file the Family Controls distribution entitlement request** (`docs/entitlement-request.md` has the submission text ready; Account Holder sign-in required). Apple lead time is days-to-weeks; everything else can proceed in parallel. Also: name-check "Scrollometer" (App Store search + USPTO + domain).
2. **WP4** (ScrollStore: GRDB schema, migrations, SharedDefaultsBridge) — spec in plan; tests are Mac-only.
3. **WP5** (MonitorExtension + MonitoringService) — CLOSEST review; keep extension free of GRDB.
4. **WP6** (onboarding + token labeling), then WP7/WP8 UI.

## Notes / decisions this session

- **Kimi background-run hazard**: `kimi-exec.sh --implement` launched via a backgrounded shell got its wrapper killed twice (harness interaction), which ORPHANS the kimi CLI process — it keeps running/writing with no timeout and locks the worktree. If it recurs: check `Get-Process kimi` (lowercase = CLI), kill orphans, reset worktree before any re-run. Consider running implement legs attended/foreground or via a scheduler that owns the process tree.
- Executor pipeline remains the plan for WP4+ once the lane is stable; WP2/3 being Claude-authored means a decorrelated cross-model audit of `Packages/ScrollCore` is still owed (Kimi audit lane per orchestrate skill) before M2 is declared done.
- `.claude/` and `.orchestrate/` are gitignored. No git remote configured yet — decide hosting (GitHub private?) at M0.
