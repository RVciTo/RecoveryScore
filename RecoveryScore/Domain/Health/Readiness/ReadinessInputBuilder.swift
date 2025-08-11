/// ReadinessInputBuilder.swift
/// Helper that builds a ReadinessInput object from raw HealthKit metrics.
///
/// This helps decouple transformation logic from UI code or view models.

import Foundation

struct ReadinessInputBuilder {

    /// Builds a `ReadinessInput` from the raw HealthKit data collected by the view model.
    /// - Parameters:
    ///   - hrv: Latest HRV sample (value and date)
    ///   - rhr: Latest RHR sample (value and date)
    ///   - hrr: Latest HRR sample (value and date)
    ///   - sleepInfo: Tuple with total sleep hours, efficiency, start/end dates, and stage map (deep/REM)
    ///   - respiratoryRate: Latest respiratory rate sample (value and date)
    ///   - wristTemp: Latest wrist temperature sample (value and date)
    ///   - oxygenSaturation: Latest O2 saturation sample (value and date)
    ///   - activeEnergyBurned: Latest active energy sample (value and date)
    ///   - mindfulMinutes: Latest mindfulness duration (value and date)
    ///   - recentWorkouts: Optional recent workouts (default empty)
    static func build(
        hrv: (Double, Date),
        rhr: (Double, Date),
        hrr: (Double, Date),
        sleepInfo: (Double, Double, Date, Date, [String: Double]),
        respiratoryRate: (Double, Date),
        wristTemp: (Double, Date),
        oxygenSaturation: (Double, Date),
        activeEnergyBurned: (Double, Date),
        mindfulMinutes: (Double, Date),
        recentWorkouts: [WorkoutSummary] = []
    ) -> ReadinessInput {
        return ReadinessInput(
            hrv: hrv.0,
            rhr: rhr.0,
            hrr: hrr.0,
            sleepHours: sleepInfo.0,
            deepSleep: sleepInfo.4["Deep"] ?? sleepInfo.4["deep"] ?? 0,
            remSleep: sleepInfo.4["REM"] ?? sleepInfo.4["rem"] ?? 0,
            respiratoryRate: respiratoryRate.0,
            wristTemp: wristTemp.0,
            o2: oxygenSaturation.0,
            energyBurned: activeEnergyBurned.0,
            mindfulMinutes: mindfulMinutes.0,
            recentWorkouts: recentWorkouts
        )
    }
}
