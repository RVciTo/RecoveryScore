# RecoveryScore

RecoveryScore gives you a daily **readiness / recovery score** using Apple Health data.
No account, on-device only, privacy-first.

## Features
- Daily **Readiness Score (0–100)**
- Clear **drivers** (what helped vs hurt)
- **Sleep** details (Core, REM, Deep)
- **Trends** sparkline
- **Help** screen for Health permissions & baselines

## How it works (high level)
We build personal baselines from your recent data (7-day rolling for biometrics;
4-week average for weekly training load). Each morning we compare today’s metrics
to your baselines and apply small bonuses/penalties. Full spec in `SCORING.md`.

## Requirements
- iPhone with Apple Health
- Apple Watch recommended (HRV, sleep stages, wrist temp, HRR)
- Third-party wearables supported if they write to Health

## Privacy
All processing is on-device. We only read Health data you authorize.
See `PRIVACY.md`.

## Build & Test
- Open in Xcode, select a simulator, **⌘U** to run tests.
- UI tests: `RecoveryScoreUITests` (single iteration launch metric to avoid flakes).

## License
© 2025 Your Name. All rights reserved.
