// HealthContextBuilder.swift
// RecoveryScore
//
// Builds a structured health data summary from recent metrics for use in AI prompts.

import Foundation

/// Provides a structured summary of recent health metrics
/// to support contextual AI chat.
public protocol HealthContextProviding {
    /// Builds a dictionary of relevant health data for the past 7 days.
    /// Keys are semantic labels (e.g., "averageHRV") and values are stringified metrics.
    func buildWeeklyHealthContext() async throws -> [String: String]
}

/// Default implementation of `HealthContextProviding`
/// Uses `HealthDataStoreProtocol` and score calculators (to be injected).
public struct HealthContextBuilder: HealthContextProviding {

    private let healthStore: HealthDataStoreProtocol
    // TODO: Inject DailyScoreCalculator / RecoveryScoreProvider as needed

    public init(healthStore: HealthDataStoreProtocol) {
        self.healthStore = healthStore
    }

    public func buildWeeklyHealthContext() async throws -> [String: String] {
        var context: [String: String] = [:]

        // HRV (sample)
        if let (hrv, _) = try? await healthStore.fetchLatestHRV() {
            context["averageHRV"] = String(format: "%.1f ms", hrv)
        }

        // Resting HR
        if let (rhr, _) = try? await healthStore.fetchLatestRestingHR() {
            context["restingHeartRate"] = String(format: "%.1f bpm", rhr)
        }

        // TODO: Add sleep, oxygen saturation, respiratory rate, wrist temp, recovery score, activity score, etc.

        return context
    }
}
