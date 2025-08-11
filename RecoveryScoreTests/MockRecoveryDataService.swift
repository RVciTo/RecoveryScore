import Foundation
@testable import RecoveryScore

final class MockRecoveryDataService: RecoveryDataServicing {
    var bundle: RecoveryDataBundle
    var shouldReturnNilBundle: Bool = false
    var fetchDelay: TimeInterval = 0.0
    var fetchCallCount: Int = 0
    
    init(bundle: RecoveryDataBundle) { 
        self.bundle = bundle 
    }
    
    convenience init() {
        // Default empty bundle for testing error cases
        self.init(bundle: RecoveryDataBundle.empty())
    }
    
    func fetchRecoveryData() async -> RecoveryDataBundle { 
        fetchCallCount += 1
        
        if fetchDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(fetchDelay * 1_000_000_000))
        }
        
        if shouldReturnNilBundle {
            return RecoveryDataBundle.empty()
        }
        
        return bundle 
    }
    
    // Helper method to simulate different data scenarios
    func simulateDataScenario(_ scenario: DataScenario) {
        switch scenario {
        case .complete:
            bundle = RecoveryDataBundle.complete()
        case .missingMandatory:
            bundle = RecoveryDataBundle.missingMandatory()
        case .missingSecondary:
            bundle = RecoveryDataBundle.missingSecondary()
        case .extremeValues:
            bundle = RecoveryDataBundle.extremeValues()
        case .empty:
            bundle = RecoveryDataBundle.empty()
        }
    }
}

enum DataScenario {
    case complete
    case missingMandatory
    case missingSecondary
    case extremeValues
    case empty
}

extension RecoveryDataBundle {
    static func baselineOnly(_ b: BaselineData) -> RecoveryDataBundle {
        .init(hrv: nil, rhr: nil, hrr: nil, respiratoryRate: nil, wristTemp: nil, oxygenSaturation: nil, activeEnergyBurned: nil, mindfulMinutes: nil, sleepInfo: nil, baseline: b)
    }
    
    static func empty() -> RecoveryDataBundle {
        .init(
            hrv: nil, rhr: nil, hrr: nil,
            respiratoryRate: nil, wristTemp: nil, oxygenSaturation: nil,
            activeEnergyBurned: nil, mindfulMinutes: nil, sleepInfo: nil,
            baseline: BaselineData(
                averageHRV: 0, averageRHR: 0, averageHRR: 0,
                averageRespiratoryRate: 0, averageWristTemp: 0,
                averageActiveEnergy: 0, averageWeeklyLoad: 0
            )
        )
    }
    
    static func complete() -> RecoveryDataBundle {
        let now = Date()
        return .init(
            hrv: (100.0, now),
            rhr: (40.0, now),
            hrr: (20.0, now),
            respiratoryRate: (16.0, now),
            wristTemp: (35.6, now),
            oxygenSaturation: (98.0, now),
            activeEnergyBurned: (400.0, now),
            mindfulMinutes: (10.0, now),
            sleepInfo: (8.0, 1.5, now, now, ["Deep": 1.5, "REM": 1.2, "Core": 5.3]),
            baseline: BaselineData(
                averageHRV: 100, averageRHR: 40, averageHRR: 20,
                averageRespiratoryRate: 16, averageWristTemp: 35.6,
                averageActiveEnergy: 400, averageWeeklyLoad: 200
            )
        )
    }
    
    static func missingMandatory() -> RecoveryDataBundle {
        let now = Date()
        return .init(
            hrv: nil,  // Missing mandatory HRV
            rhr: nil,  // Missing mandatory RHR
            hrr: (20.0, now),
            respiratoryRate: (16.0, now),
            wristTemp: (35.6, now),
            oxygenSaturation: (98.0, now),
            activeEnergyBurned: (400.0, now),
            mindfulMinutes: (10.0, now),
            sleepInfo: (8.0, 1.5, now, now, ["Deep": 1.5, "REM": 1.2, "Core": 5.3]),
            baseline: BaselineData(
                averageHRV: 100, averageRHR: 40, averageHRR: 20,
                averageRespiratoryRate: 16, averageWristTemp: 35.6,
                averageActiveEnergy: 400, averageWeeklyLoad: 200
            )
        )
    }
    
    static func missingSecondary() -> RecoveryDataBundle {
        let now = Date()
        return .init(
            hrv: (100.0, now),
            rhr: (40.0, now),
            hrr: (20.0, now),
            respiratoryRate: nil,  // Missing secondary
            wristTemp: nil,        // Missing secondary
            oxygenSaturation: nil, // Missing secondary
            activeEnergyBurned: (400.0, now),
            mindfulMinutes: nil,   // Missing secondary
            sleepInfo: (8.0, 1.5, now, now, ["Deep": 1.5, "REM": 1.2, "Core": 5.3]),
            baseline: BaselineData(
                averageHRV: 100, averageRHR: 40, averageHRR: 20,
                averageRespiratoryRate: 16, averageWristTemp: 35.6,
                averageActiveEnergy: 400, averageWeeklyLoad: 200
            )
        )
    }
    
    static func extremeValues() -> RecoveryDataBundle {
        let now = Date()
        return .init(
            hrv: (30.0, now),   // Very low (70% below baseline)
            rhr: (60.0, now),   // Very high (50% above baseline)  
            hrr: (8.0, now),    // Very low (60% below baseline)
            respiratoryRate: (25.0, now),  // Very high
            wristTemp: (37.0, now),        // High fever-like temp
            oxygenSaturation: (90.0, now), // Very low O2
            activeEnergyBurned: (1200.0, now), // Very high strain
            mindfulMinutes: (0.0, now),    // No mindfulness
            sleepInfo: (4.0, 0.3, now, now, ["Deep": 0.3, "REM": 0.5, "Core": 3.2]), // Poor sleep
            baseline: BaselineData(
                averageHRV: 100, averageRHR: 40, averageHRR: 20,
                averageRespiratoryRate: 16, averageWristTemp: 35.6,
                averageActiveEnergy: 400, averageWeeklyLoad: 200
            )
        )
    }
    
    static func perfectRecovery() -> RecoveryDataBundle {
        let now = Date()
        return .init(
            hrv: (130.0, now),  // 30% above baseline
            rhr: (35.0, now),   // 12.5% below baseline
            hrr: (26.0, now),   // 30% above baseline
            respiratoryRate: (14.0, now),  // Below baseline
            wristTemp: (35.6, now),        // Perfect baseline match
            oxygenSaturation: (99.0, now), // Excellent
            activeEnergyBurned: (300.0, now), // Below baseline (rest day)
            mindfulMinutes: (30.0, now),   // High mindfulness
            sleepInfo: (9.0, 2.2, now, now, ["Deep": 2.2, "REM": 2.0, "Core": 4.8]), // Excellent sleep
            baseline: BaselineData(
                averageHRV: 100, averageRHR: 40, averageHRR: 20,
                averageRespiratoryRate: 16, averageWristTemp: 35.6,
                averageActiveEnergy: 400, averageWeeklyLoad: 200
            )
        )
    }
}
