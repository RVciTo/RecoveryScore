/// ReadinessCalculator
/// Computes a 0–100 daily readiness score from today’s metrics vs baselines.
/// Inputs: HRV, RHR, HRR, sleep (total & deep), respiratory rate, SpO₂,
/// wrist temperature, active energy, and recent workouts (RPE × minutes).
/// Key rules:
/// - Bonuses: HRV > +20% (+10), HRR > +20% (+10)
/// - Autonomic penalties: HRV < −10% (−5), < −30% (−15); RHR > +5% (−5), > +15% (−15)
/// - Compound: HRV < −10% & RHR > +5% (−5)
/// - Sleep: total < 6h → −5 if rest day, else −10; deep < 1h → −5
/// - Respiratory: O₂ < 95% (−10); RR > +10% & O₂ < 95% (−5)
/// - Wrist temp: +0.3°C → −10 only with autonomic strain, else −5
/// - Energy: today > +20% vs 7-day avg → −10 (baseline must exist)
/// - Workouts: 7-day load > +25% vs 4-week baseline (excl current) & ≥3 workouts → −10
///             Monotony: mean/std > 2.0 with ≥4 days, ≥3 non-zero days, std > 0.01 → −5
/// Output is clamped to 0…100.
///
///
import Foundation

struct ReadinessCalculator {
    /// Computes the readiness score based on current inputs and baseline values.
    ///
    /// - Parameters:
    ///   - input: The current biometric and behavioral values.
    ///   - baseline: The user’s personalized average baselines.
    /// - Returns: A score from 0 to 100 indicating recovery and readiness level.
    func calculateScore(from input: ReadinessInput, baseline: BaselineData) -> Int {
        var score = 100

        // MARK: - HRV
        // 🫀 HRV — Relative to baseline
        let hrvChange = (input.hrv - baseline.averageHRV) / baseline.averageHRV
        if hrvChange < -0.3 {
            score -= 15
        } else if hrvChange < -0.1 {
            score -= 5
        } else if hrvChange > 0.2 {
            score += 10
        }

        // MARK: - RHR
        // ❤️ RHR — Relative to baseline (lower is better)
        let rhrChange = (input.rhr - baseline.averageRHR) / baseline.averageRHR
        if rhrChange > 0.15 {
            score -= 15
        } else if rhrChange > 0.05 {
            score -= 5
        }

        // Compound autonomic: HRV down & RHR up
        if hrvChange < -0.1 && rhrChange > 0.05 {
            score -= 5
        }

        // MARK: - HRR
        // 💓 HRR — Relative to baseline (higher is better)
        let hrrChange = (input.hrr - baseline.averageHRR) / baseline.averageHRR
        if hrrChange > 0.2 {
            score += 10
        } else if hrrChange < -0.1 {
            score -= 5
        }

        // MARK: - Rest day detection
        let now = Date()
        let restDay = input.recentWorkouts.first(where: { $0.date >= Calendar.current.date(byAdding: .hour, value: -24, to: now)! }) == nil

        // MARK: - Sleep
        // 😴 Sleep — Duration & quality
        if input.sleepHours < 6 {
            score -= restDay ? 5 : 10
        }
        if input.deepSleep < 1.0 {
            score -= 5
        }

        // MARK: - Respiratory
        // 🫁 Respiratory Rate — Relative to baseline (lower is better)
        let respiratoryRateChange = (input.respiratoryRate - baseline.averageRespiratoryRate) / baseline.averageRespiratoryRate
        if respiratoryRateChange > 0.1 {
            score -= 5
        }

        // MARK: - Oxygen Saturation
        // 🧪 Oxygen Saturation — <95% = penalty
        if input.o2 < 95 {
            score -= 10
        }

        // Compound: RR high + O2 low
        if respiratoryRateChange > 0.1 && input.o2 < 95 {
            score -= 5
        }

        // MARK: - Wrist Temperature
        // 🌡️ Wrist Temperature — Relative to baseline (higher deviation = strain)
        let wristTempChange = input.wristTemp - baseline.averageWristTemp
        if wristTempChange > 0.3 {
            // Stronger penalty only when paired with autonomic strain
            if hrvChange < -0.1 || rhrChange > 0.05 {
                score -= 10
            } else {
                score -= 5
            }
        }

        // MARK: - Energy Burned
        // 🔥 Active Energy Burned — penalty only if >20% above 7‑day average
        if baseline.averageActiveEnergy > 0 && input.energyBurned > 1.2 * baseline.averageActiveEnergy {
            score -= 10
        }

        // MARK: - Mindfulness
        // 🧘 Mindful Minutes — Bonus if present
        if input.mindfulMinutes >= 10 {
            score += 3
        }

        // MARK: - Workouts
        // 🏋️‍♀️ 7‑day cumulative load and monotony
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let weekWorkouts = input.recentWorkouts.filter { $0.date >= weekAgo }
        let dailyBuckets = Dictionary(grouping: weekWorkouts, by: { Calendar.current.startOfDay(for: $0.date) })
        let dailyLoads: [Double] = dailyBuckets.values.map { day -> Double in
            day.reduce(0.0) { $0 + (($1.rpe ?? 0) * ($1.duration / 60.0)) }
        }
        let weeklyLoad = dailyLoads.reduce(0, +)
        // Weekly load penalty only when this week's load is meaningfully above long‑term average
        if baseline.averageWeeklyLoad > 0 && weekWorkouts.count >= 3 && weeklyLoad > 1.25 * baseline.averageWeeklyLoad {
            score -= 10
        }
        // Monotony = mean / std (avoid divide by zero)
        
        let mean = dailyLoads.isEmpty ? 0 : (dailyLoads.reduce(0,+) / Double(dailyLoads.count))
        let variance = dailyLoads.reduce(0.0) { $0 + pow(($1 - mean), 2) }
        let std = dailyLoads.count > 1 ? sqrt(variance / Double(dailyLoads.count - 1)) : 0
        // Monotony guard: require enough days and meaningful variability
        let nonZeroDays = dailyLoads.filter { $0 > 0 }.count
        if dailyLoads.count >= 4 && nonZeroDays >= 3 && std > 0.01 {
            let monotony = mean / std
            if monotony > 2.0 {
                score -= 5
            }
        }
    

        return max(0, min(score, 100))
    }
}
