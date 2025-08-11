# Testing

## Unit Tests
- `ReadinessCalculatorTests`
  - HRV/RHR/HRR bonuses & penalties
  - O₂ threshold and RR+O₂ compound
  - Wrist-temp conditional penalty
  - Energy vs 7-day baseline (baseline guard)
  - Weekly-load penalty and **monotony guard** (+ all guards)
  - Clamp to 0…100

- `WeeklyLoadCalculatorTests`
  - Long-term baseline excludes current week

- `RecoveryBiometricsViewModelTests`
  - Happy path (all data present)
  - Missing mandatory → no score + error listing
  - Missing secondary → score + warning
  - Deep-sleep penalty (≤95)
  - Trend stored once/day
  - “Screenshot-like” case ≥90

## UI Tests
- `RecoveryScoreUITests`
  - Launch performance: single iteration with `XCTApplicationLaunchMetric` to avoid flakiness.

## Adding scenarios
Use mocks for the data service to set:
- Missing mandatory (HRV/RHR/HRR nil)
- Missing secondary (SpO₂, RR, temp, energy, sleep stages)
- Heavy strain (energy > baseline; high weekly load; high monotony)
- Rest day vs non-rest day
