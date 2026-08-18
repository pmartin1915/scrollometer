# Scrollometer

iOS app that estimates how far you've scrolled — in feet and miles — across your most tempting apps (TikTok, Instagram, X, YouTube, Reddit), with weekly shareable recap cards and gentle self-management nudges.

**Working name:** Scrollometer · **Bundle ID:** `com.martinapps.scrolldistance` · **iOS floor:** 17.0

## How it works (honest-estimate model)

iOS exposes no scroll events from other apps. The only legitimate signal is per-app usage time via Apple's Screen Time API (FamilyControls + DeviceActivity). Scrollometer converts:

```
minutes of use × screen-heights-per-minute (per-app velocity profile) × physical screen height = distance
```

Every velocity profile carries a citable basis (see `docs/methodology.md`). All numbers are framed in-app as estimates ("at least ~X ft").

## Repo layout

- `project.yml` — XcodeGen definition (single source of truth; `.xcodeproj` is generated, never committed)
- `Packages/ScrollCore` — pure-Foundation domain logic (conversion engine, threshold accumulation); `swift test` runs on Linux CI
- `Packages/ScrollStore` — GRDB persistence (App Group container)
- `App/`, `MonitorExtension/`, `ReportExtension/`, `OdoWidgets/` — targets
- `docs/` — Mac setup checklist, entitlement request log, methodology, on-device test script
- `ai/` — specs for delegated work packages, IDEAS.md

## Building (Mac)

```sh
brew install xcodegen
xcodegen generate
xed .
```

Then follow `docs/mac-setup-checklist.md` (App IDs, App Group, Family Controls capability, signing). Screen Time APIs do not work in the Simulator — pipeline testing requires a physical device.

## Status

Planning complete 2026-08-18. Plan of record: work packages WP1–WP10, milestones M0–M4. Critical path: Family Controls **distribution** entitlement request (weeks of Apple lead time) — see `docs/entitlement-request.md`.
