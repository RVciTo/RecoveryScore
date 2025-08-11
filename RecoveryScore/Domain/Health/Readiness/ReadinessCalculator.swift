/// ReadinessCalculator
/// Computes a 0–100 daily readiness score from today’s metrics vs baselines.
/// Inputs: HRV, RHR, HRR, sleep (total & deep), respiratory rate, SpO₂,
/// wrist temperature, active energy, and recent workouts (RPE × minutes).
/// Key rules:
/// - Bonuses: HRV > +20% (+10), HRR > +20% (+10)
/// - Autonomic penalties: HRV < −10% (−5), < −30% (−15); RHR > +5% (−5), > +15% (−15)
/// - Compound: HRV < −10% & RHR > +5% (−5)
/// - Sleep: total < 6h → −5 if rest day, else −10; deep < 1h → −5
/// - Respiratory: O₂ < 95% (−10); RR > +10% & O₂ < 95% (−5)
/// - Wrist temp: +0.3°C → −10 only with autonomic strain, else −5
/// - Energy: today > +20% vs 7-day avg → −10 (baseline must exist)
/// - Workouts: 7-day load > +25% vs 4-week baseline (excl current) & ≥3 workouts → −10
///             Monotony: mean/std > 2.0 with ≥4 days, ≥3 non-zero days, std > 0.01 → −5
/// Output is clamped to 0…100.
///
///
import Foundation

public struct ReadinessCalculator {
    /// Computes the readiness score based on current inputs and baseline values.
    ///
    /// Applies the exact scoring algorithm specified in SCORING.md, starting from 100 and
    /// applying penalties/bonuses based on deviations from personalized baselines.
    /// Includes compound rules for multiple system strain detection.
    ///
    /// - Parameters:
    ///   - input: The current biometric and behavioral values from today's data
    ///   - baseline: The user's personalized 7-day average baselines for comparison
    /// - Returns: A score from 0 to 100 indicating recovery and readiness level (clamped)
    /// - Throws: `CalculationError` if input validation fails or calculation errors occur
    /// - Note: Score calculation is deterministic and stateless for consistent results
    public func calculateScore(from input: ReadinessInput, baseline: BaselineData) throws -> Int {
        // Validate inputs before calculation
        try validateInputs(input: input, baseline: baseline)
        
        ErrorLogger.shared.debug(
            "Starting readiness score calculation",
            category: .calculation,
            context: [
                "hrv": input.hrv,
                "rhr": input.rhr,
                "hrr": input.hrr,
                "baseline_hrv": baseline.averageHRV
            ]
        )
        
        do {
            let score = try performScoreCalculation(input: input, baseline: baseline)
            
            ErrorLogger.shared.info(
                "Readiness score calculated successfully",
                category: .calculation,
                context: [
                    "score": score,
                    "algorithm": "readiness_v1"
                ]
            )
            
            return score
        } catch {
            let calcError = CalculationError.scoreCalculationFailed(
                algorithm: "readiness_v1",
                reason: error.localizedDescription
            )
            ErrorLogger.shared.log(calcError, context: ["input_validation": "passed"])
            throw calcError
        }
    }
    
    /// Validates inputs before calculation
    private func validateInputs(input: ReadinessInput, baseline: BaselineData) throws {
        ErrorLogger.shared.debug(
            "Validating readiness calculator inputs",
            category: .calculation,
            context: [
                "hrv": input.hrv,
                "rhr": input.rhr,
                "hrr": input.hrr,
                "baseline_hrv": baseline.averageHRV,
                "baseline_rhr": baseline.averageRHR,
                "baseline_hrr": baseline.averageHRR,
                "sleep_hours": input.sleepHours,
                "deep_sleep": input.deepSleep,
                "wrist_temp": input.wristTemp,
                "o2": input.o2
            ]
        )
        
        // Validate HRV
        guard input.hrv > 0 && input.hrv < 1000 else {
            ErrorLogger.shared.error(
                "HRV input validation failed: \(input.hrv)",
                category: .calculation
            )
            throw CalculationError.invalidInput(parameter: "HRV", value: input.hrv)
        }
        
        guard baseline.averageHRV > 0 else {
            ErrorLogger.shared.error(
                "Baseline HRV validation failed: \(baseline.averageHRV)",
                category: .calculation
            )
            throw CalculationError.dataValidationFailed(
                field: "baseline HRV",
                constraints: "must be > 0"
            )
        }
        
        // Validate RHR
        guard input.rhr > 0 && input.rhr < 200 else {
            ErrorLogger.shared.error(
                "RHR input validation failed: \(input.rhr)",
                category: .calculation
            )
            throw CalculationError.invalidInput(parameter: "RHR", value: input.rhr)
        }
        
        guard baseline.averageRHR > 0 else {
            ErrorLogger.shared.error(
                "Baseline RHR validation failed: \(baseline.averageRHR)",
                category: .calculation
            )
            throw CalculationError.dataValidationFailed(
                field: "baseline RHR",
                constraints: "must be > 0"
            )
        }
        
        // Validate HRR
        guard input.hrr >= 0 && input.hrr < 100 else {
            ErrorLogger.shared.error(
                "HRR input validation failed: \(input.hrr)",
                category: .calculation
            )
            throw CalculationError.invalidInput(parameter: "HRR", value: input.hrr)
        }
        
        // Validate sleep values
        if input.sleepHours < 0 || input.sleepHours > 24 {
            throw CalculationError.invalidInput(parameter: "sleepHours", value: input.sleepHours)
        }
        
        if input.deepSleep < 0 || input.deepSleep > input.sleepHours {
            throw CalculationError.invalidInput(parameter: "deepSleep", value: input.deepSleep)
        }
        
        // Validate temperature
        guard input.wristTemp > 30 && input.wristTemp < 45 else {
            throw CalculationError.invalidInput(parameter: "wristTemp", value: input.wristTemp)
        }
        
        // Validate oxygen saturation
        guard input.o2 >= 70 && input.o2 <= 100 else {
            throw CalculationError.invalidInput(parameter: "o2", value: input.o2)
        }
    }
    
    /// Performs the actual score calculation with error handling
    private func performScoreCalculation(input: ReadinessInput, baseline: BaselineData) throws -> Int {
        var score = 100

        // MARK: - HRV
        // 🫀 HRV — Relative to baseline
        let hrvChange = (input.hrv - baseline.averageHRV) / baseline.averageHRV
        if hrvChange < -0.3 {
            score -= 15
        } else if hrvChange < -0.1 {
            score -= 5
        } else if hrvChange > 0.2 {
            score += 10
        }

        // MARK: - RHR
        // ❤️ RHR — Relative to baseline (lower is better)
        let rhrChange = (input.rhr - baseline.averageRHR) / baseline.averageRHR
        if rhrChange > 0.15 {
            score -= 15
        } else if rhrChange > 0.05 {
            score -= 5
        }

        // Compound autonomic: HRV down & RHR up
        if hrvChange < -0.1 && rhrChange > 0.05 {
            score -= 5
        }

        // MARK: - HRR
        // 💓 HRR — Relative to baseline (higher is better)
        let hrrChange = (input.hrr - baseline.averageHRR) / baseline.averageHRR
        if hrrChange > 0.2 {
            score += 10
        } else if hrrChange < -0.1 {
            score -= 5
        }

        // MARK: - Rest day detection
        let now = Date()
        let restDay = input.recentWorkouts.first(where: { $0.date >= Calendar.current.date(byAdding: .hour, value: -24, to: now)! }) == nil

        // MARK: - Sleep
        // 😴 Sleep — Duration & quality
        if input.sleepHours < 6 {
            score -= restDay ? 5 : 10
        }
        if input.deepSleep < 1.0 {
            score -= 5
        }

        // MARK: - Respiratory
        // 🫁 Respiratory Rate — Relative to baseline (lower is better)
        let respiratoryRateChange = (input.respiratoryRate - baseline.averageRespiratoryRate) / baseline.averageRespiratoryRate
        if respiratoryRateChange > 0.1 {
            score -= 5
        }

        // MARK: - Oxygen Saturation
        // 🧪 Oxygen Saturation — <95% = penalty
        if input.o2 < 95 {
            score -= 10
        }

        // Compound: RR high + O2 low
        if respiratoryRateChange > 0.1 && input.o2 < 95 {
            score -= 5
        }

        // MARK: - Wrist Temperature
        // 🌡️ Wrist Temperature — Relative to baseline (higher deviation = strain)
        let wristTempChange = input.wristTemp - baseline.averageWristTemp
        if wristTempChange > 0.3 {
            // Stronger penalty only when paired with autonomic strain
            if hrvChange < -0.1 || rhrChange > 0.05 {
                score -= 10
            } else {
                score -= 5
            }
        }

        // MARK: - Energy Burned
        // 🔥 Active Energy Burned — penalty only if >20% above 7‑day average
        if baseline.averageActiveEnergy > 0 && input.energyBurned > 1.2 * baseline.averageActiveEnergy {
            score -= 10
        }

        // MARK: - Mindfulness
        // 🧘 Mindful Minutes — Bonus if present
        if input.mindfulMinutes >= 10 {
            score += 3
        }

        // MARK: - Workouts
        // 🏋️‍♀️ 7‑day cumulative load and monotony
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) else {
            throw CalculationError.algorithmError(name: "workout_analysis", details: "Failed to calculate week ago date")
        }
        
        let weekWorkouts = input.recentWorkouts.filter { $0.date >= weekAgo }
        let dailyBuckets = Dictionary(grouping: weekWorkouts, by: { Calendar.current.startOfDay(for: $0.date) })
        let dailyLoads: [Double] = dailyBuckets.values.map { day -> Double in
            day.reduce(0.0) { $0 + (($1.rpe ?? 0) * ($1.duration / 60.0)) }
        }
        let weeklyLoad = dailyLoads.reduce(0, +)
        
        // Weekly load penalty only when this week's load is meaningfully above long‑term average
        if baseline.averageWeeklyLoad > 0 && weekWorkouts.count >= 3 && weeklyLoad > 1.25 * baseline.averageWeeklyLoad {
            score -= 10
        }
        
        // Monotony = mean / std (avoid divide by zero)
        let mean = dailyLoads.isEmpty ? 0 : (dailyLoads.reduce(0,+) / Double(dailyLoads.count))
        let variance = dailyLoads.reduce(0.0) { $0 + pow(($1 - mean), 2) }
        let std = dailyLoads.count > 1 ? sqrt(variance / Double(dailyLoads.count - 1)) : 0
        
        // Monotony guard: require enough days and meaningful variability
        let nonZeroDays = dailyLoads.filter { $0 > 0 }.count
        if dailyLoads.count >= 4 && nonZeroDays >= 3 && std > 0.01 {
            let monotony = mean / std
            if monotony > 2.0 {
                score -= 5
            }
        }

        let finalScore = max(0, min(score, 100))
        
        ErrorLogger.shared.debug(
            "Score calculation breakdown",
            category: .calculation,
            context: [
                "raw_score": score,
                "final_score": finalScore,
                "hrv_change": hrvChange,
                "rhr_change": rhrChange,
                "weekly_load": weeklyLoad
            ]
        )

        return finalScore
    }
}
