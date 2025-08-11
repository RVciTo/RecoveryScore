import XCTest
import HealthKit
@testable import RecoveryScore

final class WeeklyLoadCalculatorTests: XCTestCase {
    func testAverageOfPastWeeksExcludesCurrentWeek() {
        let now = Date()
        // Build workouts; ensure current week (last 7 days) are excluded from baseline
        var workouts: [WorkoutSummary] = []
        func add(dayOffset: Int, minutes: Double, rpe: Double) {
            workouts.append(WorkoutSummary(id: UUID(), date: now.addingTimeInterval(Double(dayOffset) * -86400.0), type: HKWorkoutActivityType.running, duration: minutes * 60.0, energy: 500, rpe: rpe, rpeSource: "t"))
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
    
    func testEmptyWorkoutHistoryReturnsZero() {
        let now = Date()
        let emptyWorkouts: [WorkoutSummary] = []
        
        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: emptyWorkouts, now: now, weeks: 4)
        XCTAssertEqual(avg, 0.0)
    }
    
    func testInsufficientHistoricalDataHandling() {
        let now = Date()
        var workouts: [WorkoutSummary] = []
        
        func add(dayOffset: Int, minutes: Double, rpe: Double) {
            workouts.append(WorkoutSummary(id: UUID(), date: now.addingTimeInterval(Double(dayOffset) * -86400.0), type: HKWorkoutActivityType.running, duration: minutes * 60.0, energy: 500, rpe: rpe, rpeSource: "t"))
        }
        
        // Only one historical week (should still compute average)
        add(dayOffset: 14, minutes: 60, rpe: 5)
        add(dayOffset: 13, minutes: 60, rpe: 5)
        
        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: workouts, now: now, weeks: 4)
        XCTAssertGreaterThan(avg, 0) // Should return non-zero average from single week
        XCTAssertEqual(avg, 600.0) // 2 workouts * 60 minutes * 5 RPE = 600
    }
    
    func testCurrentWeekExclusionBoundary() {
        let now = Date()
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let justOverWeekAgo = calendar.date(byAdding: .minute, value: -1, to: weekAgo)!
        
        var workouts: [WorkoutSummary] = []
        
        // Workout exactly 7 days ago (should be excluded)
        workouts.append(WorkoutSummary(id: UUID(), date: weekAgo, type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: 5, rpeSource: "t"))
        
        // Workout just over 7 days ago (should be included)
        workouts.append(WorkoutSummary(id: UUID(), date: justOverWeekAgo, type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: 5, rpeSource: "t"))
        
        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: workouts, now: now, weeks: 4)
        XCTAssertEqual(avg, 300.0) // Only the workout just over a week ago should count (60 * 5 = 300)
    }
    
    func testPartialWeeksHandling() {
        let now = Date()
        var workouts: [WorkoutSummary] = []
        
        func add(dayOffset: Int, minutes: Double, rpe: Double) {
            workouts.append(WorkoutSummary(id: UUID(), date: now.addingTimeInterval(Double(dayOffset) * -86400.0), type: HKWorkoutActivityType.running, duration: minutes * 60.0, energy: 500, rpe: rpe, rpeSource: "t"))
        }
        
        // Week 1: Full week
        add(dayOffset: 14, minutes: 60, rpe: 5)
        add(dayOffset: 13, minutes: 60, rpe: 5)
        add(dayOffset: 12, minutes: 60, rpe: 5)
        
        // Week 2: Partial week (only 2 days with workouts)
        add(dayOffset: 21, minutes: 60, rpe: 6)
        add(dayOffset: 20, minutes: 60, rpe: 6)
        
        // Week 3: Single workout
        add(dayOffset: 28, minutes: 120, rpe: 4)
        
        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: workouts, now: now, weeks: 4)
        // Expected: (900 + 720 + 480) / 3 = 700
        XCTAssertGreaterThan(avg, 650)
        XCTAssertLessThan(avg, 750)
    }
    
    func testNilRPEHandling() {
        let now = Date()
        var workouts: [WorkoutSummary] = []
        
        // Workout with nil RPE (should be treated as 0) - placed 14 days ago
        workouts.append(WorkoutSummary(id: UUID(), date: now.addingTimeInterval(-14 * 86400.0), type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: nil, rpeSource: "t"))
        
        // Workout with valid RPE - placed 21 days ago (different week)
        workouts.append(WorkoutSummary(id: UUID(), date: now.addingTimeInterval(-21 * 86400.0), type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: 6, rpeSource: "t"))
        
        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: workouts, now: now, weeks: 4)
        // Week 1 (14 days ago): 0 * 60 = 0
        // Week 2 (21 days ago): 6 * 60 = 360  
        // Average: (0 + 360) / 2 = 180
        XCTAssertEqual(avg, 180.0)
    }
    
    func testDifferentWorkoutTypes() {
        let now = Date()
        var workouts: [WorkoutSummary] = []
        
        func add(dayOffset: Int, minutes: Double, rpe: Double, type: HKWorkoutActivityType) {
            workouts.append(WorkoutSummary(id: UUID(), date: now.addingTimeInterval(Double(dayOffset) * -86400.0), type: type, duration: minutes * 60.0, energy: 500, rpe: rpe, rpeSource: "t"))
        }
        
        // Mix of workout types across multiple weeks
        add(dayOffset: 14, minutes: 60, rpe: 5, type: HKWorkoutActivityType.running)         // Week 1: 300
        add(dayOffset: 21, minutes: 90, rpe: 4, type: HKWorkoutActivityType.cycling)         // Week 2: 360  
        add(dayOffset: 28, minutes: 45, rpe: 7, type: HKWorkoutActivityType.traditionalStrengthTraining) // Week 3: 315
        
        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: workouts, now: now, weeks: 4)
        // Expected average: (300 + 360 + 315) / 3 = 325
        XCTAssertEqual(avg, 325.0)
    }
    
    func testDateBoundaryPrecision() {
        let calendar = Calendar.current
        let now = Date()
        let exactlySevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let oneSecondOverSevenDays = calendar.date(byAdding: .second, value: -1, to: exactlySevenDaysAgo)!
        
        var workouts: [WorkoutSummary] = []
        
        // Workout exactly 7 days ago
        workouts.append(WorkoutSummary(id: UUID(), date: exactlySevenDaysAgo, type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: 5, rpeSource: "boundary"))
        
        // Workout one second over 7 days ago  
        workouts.append(WorkoutSummary(id: UUID(), date: oneSecondOverSevenDays, type: HKWorkoutActivityType.running, duration: 60*60, energy: 500, rpe: 6, rpeSource: "included"))
        
        let avg = WeeklyLoadCalculator.averageOfPastWeeks(workouts: workouts, now: now, weeks: 4)
        XCTAssertEqual(avg, 360.0) // Only the workout with RPE 6 should be included
    }
}
