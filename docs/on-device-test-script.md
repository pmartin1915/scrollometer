# On-device test script (M1 gate; re-run before every TestFlight build)

Screen Time APIs do not function in the Simulator. All steps run on a physical iPhone (iOS 17+), built from the current branch.

## A. Fresh-install onboarding
1. Delete any prior build. Install fresh.
2. Complete onboarding: authorization prompt appears → grant; pick 2–3 real apps (include TikTok or Instagram); label each with the correct chip.
3. EXPECT: finish screen states numbers appear within ~1 hour; no crash; re-opening the app does not re-run onboarding.

## B. Tracking accuracy (core M1 gate)
1. Note the time. Scroll a labeled app continuously for 10 minutes (timer running).
2. Return to Scrollometer; trigger a drain (foreground the app).
3. EXPECT: raw-minutes debug screen shows 9–10 minutes for that app (1-min bucket floor). Record actual value.
4. Repeat with a second app for 5 minutes. EXPECT 4–5.

## C. Ladder ceiling (M1 exit criterion — record findings)
1. With 5 apps selected (max), confirm monitoring registers without error (`center.activities` non-empty).
2. Over a normal day of use, compare Scrollometer's per-app minutes against Settings → Screen Time for the same apps.
3. EXPECT: within ~10% (floors always ≤ Apple's number). If systematically worse, step ladder config down to 2-min fine steps and re-test; record both results here.

## D. Midnight rollover
1. Use tracked apps in the evening. After midnight (or next morning), verify yesterday's total is sealed/preserved and today starts near zero.

## E. Failure modes
1. **Authorization revoke**: Settings → Screen Time → remove app's permission → open Scrollometer. EXPECT: graceful explainer + re-auth path, no crash.
2. **Airplane-mode day**: full offline day. EXPECT: tracking unaffected (everything is on-device).
3. **Force-quit**: force-quit Scrollometer, keep scrolling tracked apps. EXPECT: extension still accumulates; next launch drains correctly.
4. **Stall banner**: (test hook) set `meta.lastFireAt` >36 h back with zeroed days. EXPECT: "tracking hiccup" banner; tapping it restarts monitoring and clears the banner.

## F. Results log

| Date | Build | Section | Result | Notes |
|---|---|---|---|---|
