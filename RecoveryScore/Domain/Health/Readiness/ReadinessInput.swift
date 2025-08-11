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
public struct ReadinessInput {
    public let hrv: Double
    public let rhr: Double
    public let hrr: Double
    public let sleepHours: Double
    public let deepSleep: Double
    public let remSleep: Double
    public let respiratoryRate: Double
    public let wristTemp: Double
    public let o2: Double
    public let energyBurned: Double
    public let mindfulMinutes: Double
    public let recentWorkouts: [WorkoutSummary]
    
    public init(hrv: Double, rhr: Double, hrr: Double, sleepHours: Double, deepSleep: Double, remSleep: Double, respiratoryRate: Double, wristTemp: Double, o2: Double, energyBurned: Double, mindfulMinutes: Double, recentWorkouts: [WorkoutSummary]) {
        self.hrv = hrv
        self.rhr = rhr
        self.hrr = hrr
        self.sleepHours = sleepHours
        self.deepSleep = deepSleep
        self.remSleep = remSleep
        self.respiratoryRate = respiratoryRate
        self.wristTemp = wristTemp
        self.o2 = o2
        self.energyBurned = energyBurned
        self.mindfulMinutes = mindfulMinutes
        self.recentWorkouts = recentWorkouts
    }
}
