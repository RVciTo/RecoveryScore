import Foundation
@testable import RecoveryScore

final class MockRecoveryDataService: RecoveryDataServicing {
    var bundle: RecoveryDataBundle
    init(bundle: RecoveryDataBundle) { self.bundle = bundle }
    func fetchRecoveryData() async -> RecoveryDataBundle { bundle }
}

extension RecoveryDataBundle {
    static func baselineOnly(_ b: BaselineData) -> RecoveryDataBundle {
        .init(hrv: nil, rhr: nil, hrr: nil, respiratoryRate: nil, wristTemp: nil, oxygenSaturation: nil, activeEnergyBurned: nil, mindfulMinutes: nil, sleepInfo: nil, baseline: b)
    }
}
