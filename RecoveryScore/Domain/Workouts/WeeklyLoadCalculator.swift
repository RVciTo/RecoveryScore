import Foundation

/// Utility to compute weekly training load (session-RPE × minutes) and long-term averages.
enum WeeklyLoadCalculator {
    /// Returns the average weekly load across the N weeks **before** the current 7‑day window.
    /// - Parameters:
    ///   - workouts: list of workouts (date, rpe, duration).
    ///   - now: reference date (usually Date()).
    ///   - weeks: number of prior weeks to average (default 4).
    /// - Note: Excludes the last 7 days (current week) from the average.
    static func averageOfPastWeeks(workouts: [WorkoutSummary], now: Date = Date(), weeks: Int = 4) -> Double {
        let cal = Calendar.current
        let weekStart = { (d: Date) -> Date in
            cal.dateInterval(of: .weekOfYear, for: d)?.start ?? cal.startOfDay(for: d)
        }
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now)!
        let startWindow = cal.date(byAdding: .day, value: -(7 * (weeks + 1)), to: now)! // e.g., 35 days back for 4w + current

        // Consider workouts in [startWindow, sevenDaysAgo)
        let windowWorkouts = workouts.filter { $0.date >= startWindow && $0.date < sevenDaysAgo }

        let grouped = Dictionary(grouping: windowWorkouts, by: { weekStart($0.date) })
        let weeklyLoads: [Double] = grouped.values.map { day in
            day.reduce(0.0) { $0 + (Double($1.rpe ?? 0) * ($1.duration / 60.0)) }
        }

        guard !weeklyLoads.isEmpty else { return 0.0 }
        let limited = weeklyLoads.sorted(by: >).prefix(weeks) // at most N weeks
        return limited.reduce(0.0, +) / Double(limited.count)
    }
}
