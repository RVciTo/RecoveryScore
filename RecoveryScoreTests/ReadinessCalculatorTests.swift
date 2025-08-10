import XCTest
@testable import RecoveryScore

final class ReadinessCalculatorTests: XCTestCase {
    func testCalculatorRespondsToHRVAndRHR() {
        let base = BaselineData(averageHRV: 110, averageRHR: 41, averageHRR: 28, averageRespiratoryRate: 18.2, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
        var input = ReadinessInput(hrv: 110, rhr: 41, hrr: 28, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.3, respiratoryRate: 18.0, wristTemp: 35.6, o2: 98, energyBurned: 450, mindfulMinutes: 10, recentWorkouts: [])
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
}


    func testEnergyPenaltyVsBaseline() {
        let base = BaselineData(averageHRV: 110, averageRHR: 41, averageHRR: 28, averageRespiratoryRate: 18.2, averageWristTemp: 35.6, averageActiveEnergy: 500, averageWeeklyLoad: 800)
        var input = ReadinessInput(hrv: 110, rhr: 41, hrr: 28, sleepHours: 7.5, deepSleep: 1.2, remSleep: 1.3, respiratoryRate: 18.0, wristTemp: 35.6, o2: 98, energyBurned: 650, mindfulMinutes: 0, recentWorkouts: [])
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
            WorkoutSummary(id: UUID(), date: Calendar.current.date(byAdding: .day, value: -i, to: now)!, type: .running, duration: 90*60, energy: 600, rpe: 8, rpeSource: "test")
        }
        let input = ReadinessInput(hrv: 100, rhr: 40, hrr: 20, sleepHours: 7.5, deepSleep: 1.0, remSleep: 1.0, respiratoryRate: 16, wristTemp: 35.6, o2: 98, energyBurned: 400, mindfulMinutes: 0, recentWorkouts: w)
        let calc = ReadinessCalculator()
        let s = calc.calculateScore(from: input, baseline: base)
        XCTAssertLessThan(s, 90) // should penalize for high load and monotony
    }
