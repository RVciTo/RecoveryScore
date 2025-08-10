//
//  ReadinessCalculator.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 27/07/2025.
//

import Foundation

///
/// ReadinessCalculator.swift
/// Calculates a readiness score based on biometric and behavioral data.
/// Based on comparisons to personal baselines and current metrics like HRV, RHR, sleep, etc.
///

/// Calculates a readiness score based on deviation from personalized baseline metrics.
///
/// The readiness score helps determine physical and physiological recovery status
/// and is derived from multiple biometric and behavioral inputs.
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
            // Heavier penalty if Deep < 30 min
            score -= (input.deepSleep < 0.5 ? 15 : 10)
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
        // Monotony = mean / std (avoid divide by zero)
        let mean = dailyLoads.isEmpty ? 0 : (dailyLoads.reduce(0,+) / Double(dailyLoads.count))
        let variance = dailyLoads.reduce(0.0) { $0 + pow(($1 - mean), 2) }
        let std = dailyLoads.count > 1 ? sqrt(variance / Double(dailyLoads.count - 1)) : 0
        let monotony = (std > 0) ? (mean / std) : (mean > 0 ? 10 : 0)
        if baseline.averageWeeklyLoad > 0 && weeklyLoad > 1.25 * baseline.averageWeeklyLoad {
            score -= 10
        }
        if monotony > 2.0 {
            score -= 5
        }

        return max(0, min(score, 100))
    }
}
