# Scoring Model (Exact)

**Range:** 0–100 (start 100; clamp at end).

## Baselines
- **Biometrics**: 7-day averages (HRV, RHR, HRR, RR, wrist temp, active energy)
- **Weekly load**: average of the last **4 full weeks**, excluding the current 7 days.
- **Rest day**: no workouts in the last 24 hours.

## Rules
- **HRV**: < −30% → −15; < −10% → −5; > +20% → +10
- **RHR**: > +15% → −15; > +5% → −5
- **HRR**: > +20% → +10; < −10% → −5
- **Compound (autonomic)**: HRV < −10% **and** RHR > +5% → −5
- **Sleep total**: < 6h → −5 if rest day, else −10
- **Deep sleep**: < 1h → −5
- **Respiratory**: O₂ < 95% → −10
- **Compound (RR+O₂)**: RR > +10% and O₂ < 95% → −5
- **Wrist temp**: +0.3 °C → −10 only with autonomic strain; else −5
- **Active energy**: Today > +20% vs 7-day avg → −10
- **Workouts (7-day)**:
  - Load > +25% vs 4-week baseline **and** ≥3 workouts → −10
  - **Monotony**: mean/std > 2.0 with ≥4 days, ≥3 non-zero days, std > 0.01 → −5

**Clamp**: `max(0, min(score, 100))`
