# Family Controls (Distribution) entitlement request — log + submission text

**Status: SUBMITTED 2026-08-18** (via Claude-driven browser session, Perry authenticated and approved the submit). Apple's confirmation: "We'll review your request and contact you soon with a status update." **Watch pmartin1912@gmail.com** for the decision; on grant, follow "After the distribution entitlement is granted" in `mac-setup-checklist.md`.

**Process note (2026 form)**: the request is now a TEAM-level acknowledgment — prefilled name/email/Team ID plus agreeing to the Family Controls terms (primary purpose = personal device usage management; no data sharing/ads/brokers). There is no per-bundle-ID justification field anymore; the drafted text below was not needed but is kept for App Review notes reuse.

## Where

https://developer.apple.com/contact/request/family-controls-distribution — must be signed in as the **Account Holder** of the Martin Apps LLC developer account.

## What to request

File **one request covering all three Screen Time bundle IDs** (the entitlement is granted per bundle ID, and each extension target needs it too):

| Bundle ID | Target |
|---|---|
| `com.martinapps.scrolldistance` | Main app |
| `com.martinapps.scrolldistance.monitor` | DeviceActivityMonitor extension |
| `com.martinapps.scrolldistance.report` | DeviceActivityReport extension (requested now even though the screen ships later — avoids a second multi-week wait) |

(The widget extension does not use Family Controls — App Group only — so it is not part of the request.)

## Justification text (submit as-is or lightly edited)

> Scrollometer is a digital-wellbeing app that helps users understand and manage their own social media use. Using the Screen Time API with individual authorization (FamilyControls `.individual`), the user selects the apps they personally want to manage via the system FamilyActivityPicker. A DeviceActivityMonitor extension tracks their usage of those self-selected apps, and the app translates that time into an intuitive physical metaphor — the estimated distance the user has scrolled — to make screen-time totals emotionally legible.
>
> Core self-management features: users set a daily scroll-distance goal, receive an optional notification when they cross it, and get an optional evening summary and weekly review to reflect on their usage. All data is processed and stored entirely on-device; the app collects no analytics on usage data and has no server component. The DeviceActivityReport extension is used solely to display the user's own Screen Time summary alongside our estimate for transparency.
>
> We request the Family Controls distribution entitlement for the app and its DeviceActivityMonitor and DeviceActivityReport extensions.

## Log

| Date | Event |
|---|---|
| 2026-08-18 | Request text drafted; awaiting App ID creation + Account Holder filing |
