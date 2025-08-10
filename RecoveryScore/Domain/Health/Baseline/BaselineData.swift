///
/// BaselineData.swift
/// Domain model for storing user health baseline metrics.
///
/// This file defines `BaselineData` — a struct holding calculated biometric baselines
/// such as HRV, RHR, HRR, respiratory rate, and wrist temperature.
///

import Foundation
import HealthKit

/// A container holding average values for key biometric metrics over a given period.
struct BaselineData {
    let averageHRV: Double
    let averageRHR: Double
    let averageHRR: Double
    let averageRespiratoryRate: Double
    let averageWristTemp: Double
    let averageActiveEnergy: Double
    let averageWeeklyLoad: Double
}
