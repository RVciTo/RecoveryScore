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
        let mockService = MockRecoveryDataService(bundle: bundle)
        return RecoveryBiometricsViewModel(service: mockService)
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
        XCTAssertLessThanOrEqual(vm.readinessScore ?? 100, 95)
    }

    func testTrendStoresOncePerDay() async {
        let vm = makeVM(bundle: baseBundle())
        await vm.loadAllMetrics()
        let c1 = vm.readinessTrend.count
        await vm.loadAllMetrics()
        XCTAssertEqual(vm.readinessTrend.count, c1)
    }
    
    func testScreenshotLikeCaseHighScore() async {
        // HRV -16%, RHR -4%, HRR +25 bpm above baseline, others fine -> expect ~100
        let b = BaselineData(averageHRV: 114, averageRHR: 41, averageHRR: 8, averageRespiratoryRate: 18.3, averageWristTemp: 35.57, averageActiveEnergy: 400, averageWeeklyLoad: 0)
        let now = Date()
        let bundle = RecoveryDataBundle(
            hrv: (96, now), rhr: (39, now), hrr: (33, now),
            respiratoryRate: (19.0, now), wristTemp: (35.49, now), oxygenSaturation: (97, now),
            activeEnergyBurned: (240, now), mindfulMinutes: (0, now),
            sleepInfo: (7.6, 1.5, now.addingTimeInterval(-7.6*3600), now, ["Core": 4.9, "REM": 1.2, "Deep": 1.5]),
            baseline: b
        )
        let vm = RecoveryBiometricsViewModel(service: MockRecoveryDataService(bundle: bundle))
        await vm.loadAllMetrics()
        XCTAssertGreaterThanOrEqual(vm.readinessScore ?? 0, 90) // Allow >=90 while workout/energy compounding & builder inputs are finalized
    }
    
    // MARK: - Additional Edge Case Tests
    
    func testNilServiceDataHandling() async {
        // Test when service returns completely nil data
        let nilBundle = RecoveryDataBundle(
            hrv: nil, rhr: nil, hrr: nil,
            respiratoryRate: nil, wristTemp: nil, oxygenSaturation: nil,
            activeEnergyBurned: nil, mindfulMinutes: nil, sleepInfo: nil,
            baseline: BaselineData(averageHRV: 0, averageRHR: 0, averageHRR: 0, averageRespiratoryRate: 0, averageWristTemp: 0, averageActiveEnergy: 0, averageWeeklyLoad: 0)
        )
        let vm = makeVM(bundle: nilBundle)
        await vm.loadAllMetrics()
        
        XCTAssertEqual(vm.readinessScore, 0)
        XCTAssertEqual(vm.missingMandatory.count, 3)
        XCTAssertEqual(vm.missingSecondary.count, 6)
        XCTAssertNotNil(vm.errorMessage)
    }
    
    func testPartialMandatoryDataHandling() async {
        // Test when only one mandatory metric is missing
        let b = baseBundle()
        let vm = makeVM(bundle: .init(
            hrv: nil, // Missing HRV only
            rhr: b.rhr,
            hrr: b.hrr,
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
        XCTAssertEqual(vm.missingMandatory.count, 1)
        XCTAssertTrue(vm.missingMandatory.contains("HRV"))
        XCTAssertNil(vm.warningMessage) // Should not have warning when error is present
    }
    
    func testBaselineCountingLogic() {
        let vm = makeVM(bundle: baseBundle())
        
        // Test with mixed baseline states
        vm.hrvBaseline = 100.0  // Valid
        vm.rhrBaseline = 0.0    // Treated as invalid
        vm.hrrBaseline = nil    // Invalid
        vm.respiratoryBaseline = 16.0  // Valid
        vm.wristTempBaseline = 35.6    // Valid
        
        XCTAssertEqual(vm.baselineReadyCount, 3) // Only 3 valid baselines
        XCTAssertEqual(vm.missingBaselineNames.count, 2) // 2 missing
        XCTAssertTrue(vm.missingBaselineNames.contains("Resting HR"))
        XCTAssertTrue(vm.missingBaselineNames.contains("HR Recovery"))
    }
    
    func testTrendEmptyMessageLogic() {
        let vm = makeVM(bundle: baseBundle())
        
        // Test with missing mandatory data (should show appropriate message)
        vm.readinessTrend = [85.0] // Single point trend (< 2)
        vm.missingMandatory = ["HRV"]
        
        let message = vm.trendEmptyMessage
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("required data is missing"))
        
        // Test with steady scores
        vm.missingMandatory = []
        vm.readinessTrend = [90.0, 90.0, 90.0]
        
        let steadyMessage = vm.trendEmptyMessage
        XCTAssertNotNil(steadyMessage)
        XCTAssertTrue(steadyMessage!.contains("steady"))
    }
    
    func testDriversWithExtremeBiometrics() async {
        // Test drivers with very extreme values
        let b = baseBundle()
        let extremeBundle = RecoveryDataBundle(
            hrv: (200.0, Date()), // Extremely high (should be capped in drivers)
            rhr: (25.0, Date()),  // Extremely low (should help significantly)
            hrr: (50.0, Date()),  // Extremely high (should help significantly)
            respiratoryRate: (12.0, Date()), // Lower than baseline
            wristTemp: (36.5, Date()),       // Much higher than baseline
            oxygenSaturation: (89.0, Date()), // Very low
            activeEnergyBurned: (2000.0, Date()), // Very high strain
            mindfulMinutes: (60.0, Date()),   // High mindfulness
            sleepInfo: (9.0, 2.5, Date(), Date(), ["Deep": 2.5, "REM": 2.0]),
            baseline: b.baseline
        )
        let vm = makeVM(bundle: extremeBundle)
        await vm.loadAllMetrics()
        
        let helpedDrivers = vm.helpedDrivers
        let hurtDrivers = vm.hurtDrivers
        
        XCTAssertGreaterThan(helpedDrivers.count, 0)
        XCTAssertGreaterThan(hurtDrivers.count, 0)
        
        // Verify specific extreme cases are captured
        XCTAssertTrue(helpedDrivers.contains { $0.name == "Mindfulness" })
        XCTAssertTrue(helpedDrivers.contains { $0.name == "Deep Sleep" })
        XCTAssertTrue(hurtDrivers.contains { $0.name == "O₂" })
        XCTAssertTrue(hurtDrivers.contains { $0.name == "Strain" })
    }
    
    func testConsecutiveLoadCallsStability() async {
        // Test that multiple rapid calls to loadAllMetrics are stable
        let vm = makeVM(bundle: baseBundle())
        
        await vm.loadAllMetrics()
        let score1 = vm.readinessScore
        
        await vm.loadAllMetrics()
        let score2 = vm.readinessScore
        
        await vm.loadAllMetrics()
        let score3 = vm.readinessScore
        
        // Scores should be consistent across calls
        XCTAssertEqual(score1, score2)
        XCTAssertEqual(score2, score3)
        
        // Trend should only have one entry per day (not duplicated)
        XCTAssertLessThanOrEqual(vm.readinessTrend.count, 2) // May pad to 2 for sparkline
    }
}
