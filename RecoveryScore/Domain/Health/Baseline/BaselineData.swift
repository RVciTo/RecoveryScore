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
public struct BaselineData {
    public let averageHRV: Double
    public let averageRHR: Double
    public let averageHRR: Double
    public let averageRespiratoryRate: Double
    public let averageWristTemp: Double
    public let averageActiveEnergy: Double
    public let averageWeeklyLoad: Double
    
    public init(averageHRV: Double, averageRHR: Double, averageHRR: Double, averageRespiratoryRate: Double, averageWristTemp: Double, averageActiveEnergy: Double, averageWeeklyLoad: Double) {
        self.averageHRV = averageHRV
        self.averageRHR = averageRHR
        self.averageHRR = averageHRR
        self.averageRespiratoryRate = averageRespiratoryRate
        self.averageWristTemp = averageWristTemp
        self.averageActiveEnergy = averageActiveEnergy
        self.averageWeeklyLoad = averageWeeklyLoad
    }
}
