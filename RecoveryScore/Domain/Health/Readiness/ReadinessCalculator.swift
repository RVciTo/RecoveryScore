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
            score += 5
        }

        // MARK: - RHR
        // ❤️ RHR — Relative to baseline (lower is better)
        let rhrChange = (input.rhr - baseline.averageRHR) / baseline.averageRHR
        if rhrChange > 0.15 {
            score -= 15
        } else if rhrChange > 0.05 {
            score -= 5
        }

        // MARK: - HRR
        // 💓 HRR — Relative to baseline (higher is better)
        let hrrChange = (input.hrr - baseline.averageHRR) / baseline.averageHRR
        if hrrChange > 0.2 {
            score += 5
        }

        // MARK: - Sleep
        // 😴 Sleep — Duration & quality
        if input.sleepHours < 6 {
            score -= 10
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
            score -= 5
        }

        // MARK: - Wrist Temperature
        // 🌡️ Wrist Temperature — Relative to baseline (higher deviation = strain)
        let wristTempChange = input.wristTemp - baseline.averageWristTemp
        if wristTempChange > 0.3 {
            score -= 10
        }

        // MARK: - Energy Burned
        // 🔥 Active Energy Burned — High recent strain
        if input.energyBurned > 1000 {
            score -= 10
        }

        // MARK: - Mindfulness
        // 🧘 Mindful Minutes — Bonus if present
        if input.mindfulMinutes >= 10 {
            score += 3
        }

        // MARK: - Workouts
        // 🏋️‍♀️ Recent Workouts: RPE ≥ 7 and long duration (≥30 min)
        let now = Date()
        let hardWorkouts = input.recentWorkouts.filter {
            $0.date >= Calendar.current.date(byAdding: .hour, value: -48, to: now)! &&
            ($0.rpe ?? 0) >= 7 &&
            $0.duration >= 1800
        }

        if hardWorkouts.count >= 2 {
            score -= 10
        } else if hardWorkouts.count == 1 {
            score -= 5
        }

        return max(0, min(score, 100))
    }
}
