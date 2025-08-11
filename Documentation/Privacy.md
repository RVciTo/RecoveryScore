# Privacy

RecoveryScore reads Apple Health data you authorize and computes scores **on your device**.

## Data Collection & Processing

- **No account, no analytics, no tracking.**
- Health data never leaves your device.
- All calculations are performed locally on your iPhone.
- No network requests are made for scoring or data analysis.

## HealthKit Permissions Required

### Mandatory Metrics
- **Heart Rate Variability (HRV)**: For autonomic nervous system assessment
- **Resting Heart Rate**: Baseline cardiovascular fitness indicator  
- **Heart Rate Recovery**: Post-exercise recovery capability

### Optional Enhanced Metrics
- **Respiratory Rate**: Breathing pattern analysis during sleep
- **Wrist Temperature**: Body temperature variation tracking
- **Blood Oxygen Saturation**: Respiratory system efficiency
- **Active Energy Burned**: Daily activity level assessment
- **Mindful Minutes**: Stress management and recovery practices
- **Sleep Analysis**: Duration, quality, and sleep stage data
- **Workouts**: Exercise frequency, duration, and intensity (RPE)

## Data Storage & Retention

### Local Storage
- **Baseline Data**: 7-day rolling averages stored locally for score calculation
- **Trend History**: Last 7 daily readiness scores stored in UserDefaults
- **No Raw Data Storage**: Individual HealthKit samples are not persisted

### Data Lifecycle
- Baselines are recalculated daily using fresh HealthKit queries
- Historical trends automatically prune to last 7 days
- No long-term data retention beyond what's needed for current functionality

## Permission Management

- **Granular Control**: You can authorize only the metrics you want to share
- **Revocation**: Remove permissions anytime through iOS Health app → Data Sources
- **Graceful Degradation**: App continues to function with reduced accuracy when optional metrics are unavailable
- **Clear Messaging**: App clearly indicates which missing permissions affect score accuracy

## iOS Backups & Sync

- **UserDefaults Data**: Basic trend data may be included in iOS backups/sync
- **No HealthKit Data**: Raw health data is never backed up through this app
- **Restore Behavior**: After restore, baselines rebuild automatically from available HealthKit data

## Third-Party Integration

- **Wearable Support**: Data from Garmin, Fitbit, Oura, etc. supported if they sync to Apple Health
- **No Direct API Access**: App only accesses data through Apple's HealthKit framework
- **Apple's Privacy Controls**: All third-party data access subject to iOS privacy protections
