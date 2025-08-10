//
//  RecoveryBiometricsState.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 27/07/2025.
//


/// RecoveryBiometricsState.swift
/// Encapsulates all user biometric recovery data for UI state binding.
///
/// This model aggregates the most recent biometrics and readiness score.
///

import Foundation

struct RecoveryBiometricsState {
    var hrv: (Double, Date)?
    var rhr: (Double, Date)?
    var hrr: (Double, Date)?
    var respiratoryRate: (Double, Date)?
    var wristTemp: (Double, Date)?
    var oxygenSaturation: (Double, Date)?
    var activeEnergyBurned: (Double, Date)?
    var mindfulMinutes: (Double, Date)?
    var sleepInfo: (Double, Double, Date, Date, [String: Double])?
    var readinessScore: Int?

    static var empty: RecoveryBiometricsState {
        .init()
    }
} 
