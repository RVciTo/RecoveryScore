//
//  BaselineCalculator.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 27/07/2025.
//


import Foundation
import HealthKit

/// Computes biometric baselines by averaging HealthKit samples from the past 7 days.
struct BaselineCalculator {

    // MARK: - Public API

    /// Calculates average baselines concurrently from recent HealthKit data.
    func calculateBaseline() async -> BaselineData {
        async let hrv = fetchAverageHRV()
        async let rhr = fetchAverageRHR()
        async let hrr = fetchAverageHRR()
        async let respRate = fetchAverageRespiratoryRate()
        async let wristTemp = fetchAverageWristTemp()

        return BaselineData(
            averageHRV: await hrv ?? 0.0,
            averageRHR: await rhr ?? 0.0,
            averageHRR: await hrr ?? 0.0,
            averageRespiratoryRate: await respRate ?? 0.0,
            averageWristTemp: await wristTemp ?? 0.0
        )
    }

    // MARK: - Private Helpers

    func fetchAverageHRV() async -> Double? {
        await fetchAverage(.heartRateVariabilitySDNN, unit: HKUnit(from: "ms"))
    }

    func fetchAverageRHR() async -> Double? {
        await fetchAverage(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    func fetchAverageHRR() async -> Double? {
        // 1) Try native 1-minute HRR samples over the last 7 days
        if let avgNative: Double? = await withCheckedContinuation({ cont in
            HealthDataStore.shared.fetchQuantitySamples(identifier: .heartRateRecoveryOneMinute, unit: HealthKitUnitCatalog.heartRate, pastDays: 7) { values in
                guard !values.isEmpty else { cont.resume(returning: nil); return }
                cont.resume(returning: values.reduce(0, +) / Double(values.count))
            }
        }) {
            return avgNative
        }

        // 2) Fallback: derive HRR per workout across last 7 days, then average
        if #available(iOS 13.0, *) {
            let workouts = await HealthDataStore.shared.fetchWorkouts(lastNDays: 7)
            if !workouts.isEmpty {
                var derived: [Double] = []
                for w in workouts {
                    if let h = await HealthDataStore.shared.deriveHRR(for: w) {
                        derived.append(h)
                    }
                }
                if !derived.isEmpty {
                    return derived.reduce(0, +) / Double(derived.count)
                }
            }
        }

        // 3) Last resort: use the latest HRR (native or derived around latest workout)
        let latest: (Double, Date) = await withCheckedContinuation { cont in
            HealthDataStore.shared.fetchLatestHRRecovery { cont.resume(returning: $0 ?? (0, Date.distantPast)) }
        }
        if latest.0 > 0 {
            return latest.0
        }
        return nil
    }


    func fetchAverageRespiratoryRate() async -> Double? {
        await fetchAverage(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    func fetchAverageWristTemp() async -> Double? {
        await fetchAverage(.appleSleepingWristTemperature, unit: HKUnit.degreeCelsius())
    }

    private func fetchAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            HealthDataStore.shared.fetchQuantitySamples(identifier: id, unit: unit, pastDays: 7) { values in
                guard !values.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let average = values.reduce(0, +) / Double(values.count)
                continuation.resume(returning: average)
            }
        }
    }
}
