import XCTest
import HealthKit
@testable import RecoveryScore

final class ReadinessCalculatorTests: XCTestCase {
    func testCalculatorRespondsToHRVAndRHR() {
        let base = BaselineData(averageHRV: 110, averageRHR: 41, averageHRR: 28, averageRespiratoryRate: 18.2, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
        let input = ReadinessInput(hrv: 110, rhr: 41, hrr: 28, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.3, respiratoryRate: 18.0, wristTemp: 35.6, o2: 98, energyBurned: 450, mindfulMinutes: 10, recentWorkouts: [])
        let calc = ReadinessCalculator()
        let s1 = calc.calculateScore(from: input, baseline: base)
        let inputWorse = ReadinessInput(
            hrv: 70,
            rhr: 48,
            hrr: input.hrr,
            sleepHours: input.sleepHours,
            deepSleep: input.deepSleep,
            remSleep: input.remSleep,
            respiratoryRate: input.respiratoryRate,
            wristTemp: input.wristTemp,
            o2: input.o2,
            energyBurned: input.energyBurned,
            mindfulMinutes: input.mindfulMinutes,
            recentWorkouts: input.recentWorkouts
        )
        let s2 = calc.calculateScore(from: inputWorse, baseline: base)
        XCTAssertLessThan(s2, s1)
    }
    
    func testEnergyPenaltyVsBaseline() {
        let base = BaselineData(averageHRV: 110, averageRHR: 41, averageHRR: 28, averageRespiratoryRate: 18.2, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
        let input = ReadinessInput(hrv: 110, rhr: 41, hrr: 28, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.3, respiratoryRate: 18.0, wristTemp: 35.6, o2: 98, energyBurned: 650, mindfulMinutes: 0, recentWorkouts: [])
        let calc = ReadinessCalculator()
        let s = calc.calculateScore(from: input, baseline: base)
        XCTAssertLessThan(s, 100) // >20% over baseline triggers penalty
    }

    func testHRVandHRRBonuses() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
        let input = ReadinessInput(hrv: 125, rhr: 40, hrr: 25, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.2, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: [])
        let calc = ReadinessCalculator()
        let s = calc.calculateScore(from: input, baseline: base)
        // Expect +10 for HRV and +10 for HRR => at least +20 net (capped at 100)
        XCTAssertEqual(s, 100)
    }

    func testWristTempConditional() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
        let calc = ReadinessCalculator()
        // Case A: high temp without autonomic strain -> -5
        var s = calc.calculateScore(from: ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.0, respiratoryRate: 16, wristTemp: 36.0, o2: 98, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: []), baseline: base)
        XCTAssertEqual(s, 95)
        // Case B: high temp + HRV drop -> stronger penalty pathway present; expect <= 90
        s = calc.calculateScore(from: ReadinessInput(hrv: 85, rhr: 40, hrr: 20, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.0, respiratoryRate: 16, wristTemp: 36.0, o2: 98, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: []), baseline: base)
        XCTAssertLessThanOrEqual(s, 90)
    }

    func testCompoundPenalties() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
        let input = ReadinessInput(hrv: 85, rhr: 42.5, hrr: 20, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.0, respiratoryRate: 17.7, wristTemp: 35.6, o2: 94, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: [])
        let calc = ReadinessCalculator()
        let s = calc.calculateScore(from: input, baseline: base)
        // Penalties: HRV -5, RHR -5, compound -5, RR -5, O2 -10, compound -5 => total -35 => score 65
        XCTAssertLessThanOrEqual(s, 70)
    }

    func testWorkoutLoadPenaltyAndMonotony() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 200) // baseline week load
        let now = Date()
        // Create highly repetitive high-load week (monotony high + load > 25% baseline)
        let w: [WorkoutSummary] = (0..<5).map { i in
            WorkoutSummary(id: UUID(), date: Calendar.current.date(byAdding: .day, value: -i, to: now)!, type: HKWorkoutActivityType.running, duration: 90*60, energy: 600, rpe: 8, rpeSource: "test")
        }
        let input = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 7.5, deepSleep: 1.0, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: w)
        let calc = ReadinessCalculator()
        let s = calc.calculateScore(from: input, baseline: base)
        XCTAssertLessThanOrEqual(s, 90) // should penalize for high load and monotony
    }


    func testMonotonyGuard() {
        // Baseline weekly load small but defined
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 400, averageWeeklyLoad: 200)
        let now = Date()
        // Only 2 workouts -> should NOT compute monotony, no penalty
        let w2 = [
            WorkoutSummary(id: UUID(), date: now.addingTimeInterval(-3600*24*1), type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: 7, rpeSource: "t"),
            WorkoutSummary(id: UUID(), date: now.addingTimeInterval(-3600*24*3), type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: 7, rpeSource: "t")
        ]
        let input2 = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: w2)
        let s2 = ReadinessCalculator().calculateScore(from: input2, baseline: base)
        XCTAssertEqual(s2, 100)
    }

    func testWeeklyLoadPenaltyRequiresBaselineAndCount() {
        // Baseline load defined; create load > 25% over baseline with >=3 workouts => penalty expected
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 400, averageWeeklyLoad: 200)
        let now = Date()
        let w = (0..<4).map { i in WorkoutSummary(id: UUID(), date: now.addingTimeInterval(Double(-i*86400)), type: HKWorkoutActivityType.running, duration: 90*60, energy: 600, rpe: 8, rpeSource: "t") }
        let s = ReadinessCalculator().calculateScore(from: ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: w), baseline: base)
        XCTAssertLessThan(s, 100)
    }
    
    // MARK: - Boundary Condition Tests
    
    func testExtremeHRVValues() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 400, averageWeeklyLoad: 200)
        let calc = ReadinessCalculator()
        
        // Test very low HRV (should trigger maximum penalty)
        let extremeLowHRV = ReadinessInput(hrv: 30, rhr: 40, hrr: 20, sleepHours: 8, deepSleep: 1.5, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        let scoreLow = calc.calculateScore(from: extremeLowHRV, baseline: base)
        XCTAssertLessThanOrEqual(scoreLow, 85) // Should have -15 penalty
        
        // Test very high HRV (should trigger bonus, capped at 100)
        let extremeHighHRV = ReadinessInput(hrv: 150, rhr: 40, hrr: 20, sleepHours: 8, deepSleep: 1.5, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        let scoreHigh = calc.calculateScore(from: extremeHighHRV, baseline: base)
        XCTAssertEqual(scoreHigh, 100) // Should be capped at 100
    }
    
    func testZeroBaselineHandling() {
        let zeroBaseline = BaselineData(averageHRV: 0, averageRHR: 0, averageHRR: 0, averageRespiratoryRate: 0, averageWristTemp: 0, averageActiveEnergy: 0, averageWeeklyLoad: 0)
        let input = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 8, deepSleep: 1.5, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        
        let score = ReadinessCalculator().calculateScore(from: input, baseline: zeroBaseline)
        // Should not crash with division by zero
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }
    
    func testEmptyWorkoutArray() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 400, averageWeeklyLoad: 200)
        let input = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 8, deepSleep: 1.5, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        
        let score = ReadinessCalculator().calculateScore(from: input, baseline: base)
        XCTAssertEqual(score, 100) // No workout penalties should apply
    }
    
    func testSleepBoundaryConditions() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 400, averageWeeklyLoad: 200)
        let calc = ReadinessCalculator()
        
        // Test exactly 6 hours sleep (boundary)
        let exactBoundary = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 6.0, deepSleep: 1.0, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        let scoreBoundary = calc.calculateScore(from: exactBoundary, baseline: base)
        XCTAssertEqual(scoreBoundary, 100) // Should not trigger penalty at exactly 6h
        
        // Test just under 6 hours (should trigger penalty)
        let underBoundary = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 5.9, deepSleep: 1.0, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        let scoreUnder = calc.calculateScore(from: underBoundary, baseline: base)
        XCTAssertLessThan(scoreUnder, 100) // Should trigger penalty
    }
    
    func testOxygenSaturationBoundary() {
        let base = BaselineData(averageHRV: 100, averageRHR: 40, averageHRR: 20, averageRespiratoryRate: 16, averageWristTemp: 35.6, averageActiveEnergy: 400, averageWeeklyLoad: 200)
        let calc = ReadinessCalculator()
        
        // Test exactly 95% O2 (boundary)
        let exactBoundary = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 8, deepSleep: 1.5, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 95.0, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        let scoreBoundary = calc.calculateScore(from: exactBoundary, baseline: base)
        XCTAssertEqual(scoreBoundary, 100) // Should not trigger penalty at exactly 95%
        
        // Test just under 95% (should trigger penalty)
        let underBoundary = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 8, deepSleep: 1.5, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 94.9, energyBurned: 300, mindfulMinutes: 0, recentWorkouts: [])
        let scoreUnder = calc.calculateScore(from: underBoundary, baseline: base)
        XCTAssertLessThanOrEqual(scoreUnder, 90) // Should trigger -10 penalty
    }
}
    