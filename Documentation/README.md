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
4-week average for weekly training load). Each morning we compare today's metrics
to your baselines and apply small bonuses/penalties. Full spec in `SCORING.md`.

## Architecture

### Directory Structure
```
RecoveryScore/
├── Data/Remote/           # HealthKit data access layer
│   └── HealthDataStore.swift
├── Domain/                # Business logic & models
│   ├── Health/
│   │   ├── Baseline/      # 7-day baseline calculations
│   │   ├── Context/       # Health data protocols
│   │   └── Readiness/     # Score calculation engine
│   ├── Recovery/Models/   # Recovery-specific data models
│   └── Workouts/Models/   # Workout analysis & load calculation
├── Feature/               # UI layer organized by feature
│   ├── Common/View/       # Shared UI components
│   ├── Recovery/          # Main recovery score interface
│   └── Settings/          # Permissions & configuration
└── Tests/                 # Unit & UI tests
```

### Key Algorithms

#### Readiness Calculation
1. **Baseline Generation**: 7-day rolling averages for biometrics (HRV, RHR, HRR, respiratory rate, wrist temperature)
2. **Relative Scoring**: Compare today's metrics to personal baselines using percentage changes
3. **Penalty/Bonus System**: Apply weighted adjustments based on deviation thresholds
4. **Compound Rules**: Additional penalties when multiple systems show strain simultaneously

#### Data Flow
```
HealthKit → HealthDataStore → BaselineCalculator → ReadinessCalculator → UI
                           ↓
                    RecoveryDataService → RecoveryBiometricsViewModel
```

### Core Components

- **ReadinessCalculator**: Core scoring algorithm implementing the exact rules from `SCORING.md`
- **BaselineCalculator**: Computes personal baselines using concurrent HealthKit queries  
- **RecoveryBiometricsViewModel**: Main view model coordinating data fetching and UI updates
- **HealthDataStore**: Singleton managing all HealthKit interactions and permissions

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
