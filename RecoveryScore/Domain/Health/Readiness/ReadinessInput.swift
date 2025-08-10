//
//  ReadinessInput.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 27/07/2025.
//


//
//  ReadinessInput.swift
//  Athletica.OS
//
//  Created by Frova Hervé on 25/07/2025.
//

import Foundation

/// Domain model for computing readiness from various biometrics.
struct ReadinessInput {
    let hrv: Double
    let rhr: Double
    let hrr: Double
    let sleepHours: Double
    let deepSleep: Double
    let remSleep: Double
    let respiratoryRate: Double
    let wristTemp: Double
    let o2: Double
    let energyBurned: Double
    let mindfulMinutes: Double
    let recentWorkouts: [WorkoutSummary]
}
