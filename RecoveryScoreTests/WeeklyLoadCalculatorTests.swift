import XCTest
@testable import RecoveryScore

final class WeeklyLoadCalculatorTests: XCTestCase {
    func testAverageOfPastWeeksExcludesCurrentWeek() {
        let now = Date()
        // Build workouts; ensure current week (last 7 days) are excluded from baseline
        var workouts: [WorkoutSummary] = []
        func add(dayOffset: Int, minutes: Double, rpe: Double) {
            workouts.append(WorkoutSummary(id: UUID(), date: now.addingTimeInterval(Double(dayOffset) * -86400.0), type: .running, duration: minutes * 60.0, energy: 500, rpe: rpe, rpeSource: "t"))
        }
        // Historical: three weeks
        add(dayOffset: 28, minutes: 60, rpe: 5); add(dayOffset: 27, minutes: 60, rpe: 5); add(dayOffset: 26, minutes: 60, rpe: 5) // 900
        add(dayOffset: 21, minutes: 60, rpe: 5); add(dayOffset: 20, minutes: 60, rpe: 5); add(dayOffset: 19, minutes: 60, rpe: 5) // 900
        add(dayOffset: 14, minutes: 60, rpe: 6); add(dayOffset: 13, minutes: 60, rpe: 6) // 720

        // Current week high load (excluded)
        add(dayOffset: 1, minutes: 90, rpe: 8); add(dayOffset: 2, minutes: 90, rpe: 8); add(dayOffset: 3, minutes: 90, rpe: 8); add(dayOffset: 4, minutes: 90, rpe: 8); add(dayOffset: 5, minutes: 90, rpe: 8)

        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: workouts, now: now, weeks: 4)
        // Expected average around (900 + 900 + 720) / 3 = 840
        XCTAssertGreaterThan(avg, 700)
        XCTAssertLessThan(avg, 950)
    }
}
