//
//  BaselineCalculator.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 27/07/2025.
//


import Foundation
import HealthKit

/// Protocol for baseline calculation to enable dependency injection
public protocol BaselineCalculatorProtocol {
    func calculateBaseline() async -> BaselineData
}

/// Computes biometric baselines by averaging HealthKit samples from the past 7 days.
public struct BaselineCalculator: BaselineCalculatorProtocol {
    
    private let healthDataStore: HealthDataStore
    
    /// Initializes the calculator with a health data store
    /// - Parameter healthDataStore: The health data store to use for fetching data
    public init(healthDataStore: HealthDataStore = HealthDataStore.shared) {
        self.healthDataStore = healthDataStore
    }

    // MARK: - Public API

    /// Calculates average baselines concurrently from recent HealthKit data.
    ///
    /// Computes 7-day rolling averages for core biometric indicators used in readiness scoring.
    /// Uses concurrent async operations for optimal performance when fetching multiple metrics.
    ///
    /// - Returns: BaselineData containing computed averages, with reasonable defaults for unavailable metrics
    /// - Note: Active energy and weekly load baselines are computed separately via other services
    public func calculateBaseline() async -> BaselineData {
        async let hrv = fetchAverageHRV()
        async let rhr = fetchAverageRHR()
        async let hrr = fetchAverageHRR()
        async let respRate = fetchAverageRespiratoryRate()
        async let wristTemp = fetchAverageWristTemp()

        let hrvValue = await hrv ?? 50.0  // Reasonable default HRV baseline (ms)
        let rhrValue = await rhr ?? 65.0  // Reasonable default RHR baseline (bpm)
        let hrrValue = await hrr ?? 25.0  // Reasonable default HRR baseline (bpm)
        let respValue = await respRate ?? 16.0  // Reasonable default respiratory rate (breaths/min)
        let wristTempValue = await wristTemp ?? 36.5  // Reasonable default wrist temperature (°C)
        
        // Log when we're using defaults vs actual computed baselines
        ErrorLogger.shared.debug(
            "Baseline calculation completed",
            category: .healthData,
            context: [
                "hrv": hrvValue,
                "rhr": rhrValue,
                "hrr": hrrValue,
                "using_hrv_default": await hrv == nil,
                "using_rhr_default": await rhr == nil,
                "using_hrr_default": await hrr == nil
            ]
        )

        return BaselineData(
            averageHRV: hrvValue,
            averageRHR: rhrValue,
            averageHRR: hrrValue,
            averageRespiratoryRate: respValue,
            averageWristTemp: wristTempValue,
            averageActiveEnergy: 0.0,
            averageWeeklyLoad: 0.0)
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
            healthDataStore.fetchQuantitySamples(identifier: .heartRateRecoveryOneMinute, unit: HealthKitUnitCatalog.heartRate, pastDays: 7) { values in
                guard !values.isEmpty else { cont.resume(returning: nil); return }
                cont.resume(returning: values.reduce(0, +) / Double(values.count))
            }
        }) {
            return avgNative
        }

        // 2) Fallback: derive HRR per workout across last 7 days, then average
        if #available(iOS 13.0, *) {
            let workouts = await healthDataStore.fetchWorkouts(lastNDays: 7)
            if !workouts.isEmpty {
                var derived: [Double] = []
                for w in workouts {
                    if let h = await healthDataStore.deriveHRR(for: w) {
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
            healthDataStore.fetchLatestHRRecovery { cont.resume(returning: $0 ?? (0, Date.distantPast)) }
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
            healthDataStore.fetchQuantitySamples(identifier: id, unit: unit, pastDays: 7) { values in
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
