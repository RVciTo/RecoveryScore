import XCTest
@testable import RecoveryScore

@MainActor
final class RecoveryBiometricsViewModelTests: XCTestCase {
    func makeBaseline() -> BaselineData {
        .init(averageHRV: 110, averageRHR: 41, averageHRR: 28, averageRespiratoryRate: 18.2, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
    }

    func baseBundle() -> RecoveryDataBundle {
        .init(
            hrv: (110, Date()),
            rhr: (40, Date()),
            hrr: (30, Date()),
            respiratoryRate: (18.0, Date()),
            wristTemp: (35.6, Date()),
            oxygenSaturation: (98, Date()),
            activeEnergyBurned: (450, Date()),
            mindfulMinutes: (0, Date()),
            sleepInfo: (7.5, 1.2, Date().addingTimeInterval(-7.5*3600), Date(), ["Core": 5.0, "REM": 1.3, "Deep": 1.2]),
            baseline: makeBaseline()
        )
    }

    func makeVM(bundle: RecoveryDataBundle) -> RecoveryBiometricsViewModel {
        RecoveryBiometricsViewModel(service: MockRecoveryDataService(bundle: bundle))
    }

    func testHighReadiness_AllDataPresent() async {
        let vm = makeVM(bundle: baseBundle())
        await vm.loadAllMetrics()
        XCTAssertNotNil(vm.readinessScore)
        XCTAssertGreaterThanOrEqual(vm.readinessScore ?? 0, 80)
        XCTAssertNil(vm.errorMessage)
    }

    func testMissingMandatory_NoScore() async {
        let b = baseBundle()
        let vm = makeVM(bundle: .init(
            hrv: b.hrv,
            rhr: b.rhr,
            hrr: nil, // mandatory missing
            respiratoryRate: b.respiratoryRate,
            wristTemp: b.wristTemp,
            oxygenSaturation: b.oxygenSaturation,
            activeEnergyBurned: b.activeEnergyBurned,
            mindfulMinutes: b.mindfulMinutes,
            sleepInfo: b.sleepInfo,
            baseline: b.baseline
        ))
        await vm.loadAllMetrics()
        XCTAssertEqual(vm.readinessScore, 0)
        XCTAssertTrue(vm.errorMessage?.contains("HR Recovery") == true)
    }

    func testMissingSecondary_WarningButScore() async {
        let b = baseBundle()
        let vm = makeVM(bundle: .init(
            hrv: b.hrv,
            rhr: b.rhr,
            hrr: b.hrr,
            respiratoryRate: b.respiratoryRate,
            wristTemp: b.wristTemp,
            oxygenSaturation: nil, // secondary missing
            activeEnergyBurned: b.activeEnergyBurned,
            mindfulMinutes: b.mindfulMinutes,
            sleepInfo: b.sleepInfo,
            baseline: b.baseline
        ))
        await vm.loadAllMetrics()
        XCTAssertNotNil(vm.readinessScore)
        XCTAssertNotNil(vm.warningMessage)
        XCTAssertNil(vm.errorMessage)
    }

    func testDeepSleepPenalty() async {
        let b = baseBundle()
        let vm = makeVM(bundle: .init(
            hrv: b.hrv,
            rhr: b.rhr,
            hrr: b.hrr,
            respiratoryRate: b.respiratoryRate,
            wristTemp: b.wristTemp,
            oxygenSaturation: b.oxygenSaturation,
            activeEnergyBurned: b.activeEnergyBurned,
            mindfulMinutes: b.mindfulMinutes,
            sleepInfo: (6.0, 0.5, Date().addingTimeInterval(-6*3600), Date(), ["Core":4.5, "REM":1.0, "Deep":0.5]),
            baseline: b.baseline
        ))
        await vm.loadAllMetrics()
        XCTAssertLessThan(vm.readinessScore ?? 100, 95)
    }

    func testTrendStoresOncePerDay() async {
        let vm = makeVM(bundle: baseBundle())
        await vm.loadAllMetrics()
        let c1 = vm.readinessTrend.count
        await vm.loadAllMetrics()
        XCTAssertEqual(vm.readinessTrend.count, c1)
    }
}
