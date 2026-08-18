# How Scrollometer calculates your scroll distance

This document is the source of truth for the in-app Methodology page. The in-app page must stay consistent with the shipped `velocity_table_vN.json` (single source: the page derives its numbers from the bundled table at runtime, never from hardcoded copy).

## The honest framing

Scrollometer shows **estimates, not measurements**. iOS does not allow any app to observe scrolling inside other apps — that's a privacy feature, and we think it's a good one. What iOS does provide (with your permission, via Apple's Screen Time framework) is how much **time** you spend in the apps you choose to track. Everything is computed on your device; we never see your data.

## The formula

```
distance = minutes of use × screen-heights scrolled per minute × your screen's physical height
```

- **Minutes of use** comes from Apple's Screen Time monitoring of the apps you selected. It arrives in ~1-minute increments, so totals are floors — "at least X."
- **Screen-heights per minute** is a per-app velocity profile (below).
- **Your screen's physical height** comes from your iPhone model (e.g., an iPhone 15's display is ~5.81 inches tall).

## Velocity profiles (v1 seeds — calibrated in WP2)

| Profile | Screen-heights/min | Basis |
|---|---|---|
| TikTok | 7.1 | Avg watch time ~8.4 s/video (Statista 2024); one full-screen swipe per video |
| Instagram | 6.5 | Reels avg watch 6–10 s blended with slower feed/grid browsing |
| YouTube | 4.5 | Shorts watch times run longer; long-form viewing dampens the average |
| X | 9.0 | Text-feed scrolling, calibrated against Robertson et al. 2024 (~300 ft/day aggregate) |
| Reddit | 8.0 | Mixed text/media feed |
| Other (video) | 6.0 | Generic short-form default |
| Other (text) | 8.5 | Generic text-feed default |

Calibration cross-check: at typical daily usage mixes, these profiles should land in the same range as the peer-reviewed aggregate (~300 ft/day for average social feed use — Robertson, del Rosario & Van Bavel, 2024, "Inside the Funhouse Mirror Factory," Current Opinion in Psychology). WP2's acceptance criteria include this reconciliation.

## Citable external reference points

1. **Robertson, del Rosario & Van Bavel (2024)** — peer-reviewed; average user scrolls ~300 ft/day ("a Statue of Liberty a day"). Primary citation.
2. **Saucony × HarrisX (2024)** — commercial survey; 78 miles/year ("three marathons").
3. **TollFreeForwarding (2023)** — transparent-formula PR study; ~86 miles/year US average.

We do not cite unsourced "Everest a year"-style claims.

## Known limitations (also disclosed in-app)

- Minutes arrive in coarse buckets; brief sessions may undercount. All totals read "at least."
- Time in an app isn't all scrolling (typing a comment, watching a full video). Velocity profiles are averages across real usage patterns, which is why per-app profiles differ.
- iOS occasionally drops monitoring events; Scrollometer detects stalls and offers a one-tap restart.
- History is stored on-device only and does not sync across devices in v1.
