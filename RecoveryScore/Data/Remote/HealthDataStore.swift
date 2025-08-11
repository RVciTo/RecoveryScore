/// HealthDataStore.swift
///
/// Data‑layer component that wraps HealthKit on‑device storage.
/// Provides read‑only access to health and activity metrics needed by Athletica’s
/// offline build.
///
/// TODO: – Conform to `HealthDataStoreProtocol` and move to `Data/HealthKit` package
///       when we introduce the dependency‑injection container.

import HealthKit
import HealthKitUI
import UIKit

/// Protocol defining HealthKit data access methods for Athletica.
public protocol HealthDataStoreProtocol {
    /// Requests HealthKit authorization.
    /// - Throws: `HealthDataError.notAuthorized` if authorization failed.
    @available(iOS 13.0, *)
    func requestAuthorization() async throws

    /// Fetches the most recent Heart Rate Variability (SDNN) sample.
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchLatestHRV() async throws -> (Double, Date)

    /// Fetches the most recent resting heart rate sample.
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchLatestRestingHR() async throws -> (Double, Date)

    /// Fetches the most recent heart rate recovery (1-min) sample.
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchLatestHRRecovery() async throws -> (Double, Date)

    /// Fetches the most recent respiratory rate sample.
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchLatestRespiratoryRate() async throws -> (Double, Date)

    /// Provides a continuous asynchronous stream of heart rate (BPM) samples.
    /// - Returns: AsyncThrowingStream yielding (value, timestamp) tuples as new data arrives.
    @available(iOS 13.0, *)
    func heartRateStream() -> AsyncThrowingStream<(Double, Date), Error>
}

/// Errors thrown by HealthDataStore.
public enum HealthDataError: Error {
    /// Authorization request was denied.
    case notAuthorized
    /// No sample data available for the requested metric.
    case sampleUnavailable
    /// Underlying error from HealthKit.
    case underlyingError(Error)
}

/// Centralized HealthKit unit definitions used across HealthDataStore.
public enum HealthKitUnitCatalog {
    /// Heart Rate Variability: milliseconds
    public static let hrv = HKUnit.secondUnit(with: .milli)
    /// Resting and recovery heart rate: beats per minute
    public static let heartRate = HKUnit.count().unitDivided(by: .minute())
    /// Respiratory rate: breaths per minute
    public static let respiratoryRate = HKUnit.count().unitDivided(by: .minute())
    /// Active energy burned: kilocalories
    public static let activeEnergy = HKUnit.kilocalorie()
    /// Oxygen saturation: percent
    public static let oxygenSaturation = HKUnit.percent()
    /// Wrist temperature: degrees Celsius
    public static let wristTemperature = HKUnit.degreeCelsius()
    /// Nutrition units
    public static let dietaryWater = HKUnit.literUnit(with: .milli)         // milliliters
    public static let dietaryCaffeine = HKUnit.gramUnit(with: .milli)       // milligrams
    public static let dietaryProtein = HKUnit.gram()                         // grams
    public static let dietaryCarbohydrates = HKUnit.gram()                   // grams
    public static let dietaryFats = HKUnit.gram()                            // grams
    public static let dietaryCalcium = HKUnit.gramUnit(with: .milli)        // milligrams
    public static let dietaryIron = HKUnit.gramUnit(with: .milli)           // milligrams
    public static let dietaryMagnesium = HKUnit.gramUnit(with: .milli)      // milligrams
    public static let dietarySelenium = HKUnit.gramUnit(with: .milli)       // milligrams
    public static let dietaryVitaminB6 = HKUnit.gramUnit(with: .milli)      // milligrams
    public static let dietaryVitaminB12 = HKUnit.gramUnit(with: .milli)     // milligrams
    public static let dietaryVitaminD = HKUnit.gramUnit(with: .milli)       // milligrams
    // TODO: Add units for other new metrics (e.g., VO2Max, distance, etc.)
}
public final class HealthDataStore {
    public static let shared = HealthDataStore()
    /// Underlying HealthKit store for queries and authorization requests.
    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - Caching Layer

    /// Time interval in seconds to keep cached values before re-fetching.
    private let cacheExpiration: TimeInterval = 300 // 5 minutes

    /// In-memory cache storage mapping keys to timestamped values.
    private var cache = [String: (Date, Any)]()

    /// Helper to fetch and cache results of HealthKit queries.
    ///
    /// - Parameters:
    ///   - key: Unique cache key.
    ///   - fetcher: Async closure that performs the real fetch.
    /// - Returns: The fetched or cached value.
    private func fetchWithCache<T>(_ key: String, fetcher: @escaping () async throws -> T) async throws -> T {
        if let (date, cached) = cache[key] as? (Date, T), Date().timeIntervalSince(date) < cacheExpiration {
            return cached
        }
        let result = try await fetcher()
        cache[key] = (Date(), result)
        return result
    }

    /// The set of HealthKit data types that the app will request read access for.
    ///
    /// Built dynamically so we can compile on older SDKs: any identifier unavailable in
    /// the current runtime is silently skipped.
    private static let defaultReadTypes: Set<HKObjectType> = {
        var set = Set<HKObjectType>()
        func add(_ id: HKQuantityTypeIdentifier) {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                set.insert(type)
            }
        }
        func addCategory(_ id: HKCategoryTypeIdentifier) {
            if let type = HKObjectType.categoryType(forIdentifier: id) {
                set.insert(type)
            }
        }
        // Mandatory — baselines
        add(.heartRateVariabilitySDNN)   // HRV
        add(.restingHeartRate)           // RHR
        // HRR is derived from heart rate/workouts; include heartRate + workouts
        add(.heartRate)
        set.insert(HKObjectType.workoutType())

        // Secondary — baselines
        add(.respiratoryRate)
        add(.appleSleepingWristTemperature)

        // Secondary — standards
        add(.oxygenSaturation)
        add(.activeEnergyBurned)
        addCategory(.mindfulSession)
        addCategory(.sleepAnalysis)

        return set
    }()

    /// Instance‑level exposure of the computed read types.
    let readTypes: Set<HKObjectType> = HealthDataStore.defaultReadTypes

    /// Requests HealthKit authorization for the predefined `readTypes`.
    ///
    /// - Parameter completion: Called on the main thread with `true` if authorization succeeded.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        print("HKManager.requestAuthorization called")
        // If workouts are already authorized, no need to prompt again
        let status = healthStore.authorizationStatus(for: .workoutType())
        if status == .sharingAuthorized {
            print("HK already authorized ✔︎")
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if let error = error {
                print("HK auth error: \(error.localizedDescription)")
            } else {
                print("HK auth prompt finished. success = \(success)")
            }
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    /// Fetches the most recent health samples.
    ///
    /// - Parameter completion: Returns a tuple of value and timestamp, or `nil` if unavailable.
    func fetchLatestHRV(completion: @escaping ((Double, Date)?) -> Void) {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }
        fetchLatestQuantitySample(for: hrvType, unit: HealthKitUnitCatalog.hrv, completion: completion)
    }

    func fetchLatestRestingHR(completion: @escaping ((Double, Date)?) -> Void) {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }
        fetchLatestQuantitySample(for: rhrType, unit: HealthKitUnitCatalog.heartRate, completion: completion)
    }

    func fetchLatestHRRecovery(completion: @escaping ((Double, Date)?) -> Void) {
        guard let hrrType = HKQuantityType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) else {
            completion(nil)
            return
        }
        // First, try to fetch direct HRR sample
        fetchLatestQuantitySample(for: hrrType, unit: HealthKitUnitCatalog.heartRate) { [weak self] result in
            if let result = result {
                completion(result)
                return
            }
            // Fallback: calculate from workout and heart rate samples
            guard let self = self,
                  let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
            else {
                completion(nil)
                return
            }
            // Fetch the most recent workout
            let workoutSort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let workoutQuery = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: 1, sortDescriptors: [workoutSort]) { [weak self] _, workoutSamples, _ in
                guard let workout = workoutSamples?.first as? HKWorkout else {
                    completion(nil)
                    return
                }
                // Define window: one minute before end to one minute after end
                let workoutStart = workout.startDate
                let workoutEnd = workout.endDate
                let afterEnd = workoutEnd.addingTimeInterval(60)
                // Fetch HR samples from workoutStart to one minute after workoutEnd
                let hrPredicate = HKQuery.predicateForSamples(withStart: workoutStart, end: afterEnd, options: .strictStartDate)
                let hrSort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
                let hrQuery = HKSampleQuery(sampleType: hrType, predicate: hrPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [hrSort]) { _, hrSamples, _ in
                    guard let hrSamples = hrSamples as? [HKQuantitySample], !hrSamples.isEmpty else {
                        completion(nil)
                        return
                    }
                    // Find peak HR during exercise (from workoutStart to workoutEnd)
                    let exerciseSamples = hrSamples.filter { $0.startDate >= workoutStart && $0.endDate <= workoutEnd }
                    let peakHR = exerciseSamples.map { $0.quantity.doubleValue(for: HealthKitUnitCatalog.heartRate) }.max()
                    // Find HR at one minute after workoutEnd (closest sample >= workoutEnd+60s)
                    let oneMinAfter = workoutEnd.addingTimeInterval(60)
                    // Find sample with endDate just after or closest to oneMinAfter
                    let postSamples = hrSamples.filter { $0.endDate >= oneMinAfter }
                    let hr1mSample = postSamples.min(by: { abs($0.endDate.timeIntervalSince(oneMinAfter)) < abs($1.endDate.timeIntervalSince(oneMinAfter)) })
                        ?? hrSamples.last // fallback to last sample if no sample after 1 min
                    let hr1m = hr1mSample?.quantity.doubleValue(for: HealthKitUnitCatalog.heartRate)
                    if let peak = peakHR, let hr1m = hr1m {
                        let hrr = peak - hr1m
                        completion((hrr, workoutEnd))
                    } else {
                        completion(nil)
                    }
                }
                self?.healthStore.execute(hrQuery)
            }
            self.healthStore.execute(workoutQuery)
        }
    }

    func fetchLatestRespiratoryRate(completion: @escaping ((Double, Date)?) -> Void) {
        guard let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(nil)
            return
        }
        fetchLatestQuantitySample(for: respType, unit: HealthKitUnitCatalog.respiratoryRate, completion: completion)
    }

    func fetchLastNightSleep(completion: @escaping ((Double, Double, Date, Date, [String: Double])?) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .hour, value: -36, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        let sampleTypes = [sleepType]
        let dispatchGroup = DispatchGroup()

        var allSamples: [HKCategorySample] = []

        for type in sampleTypes {
            dispatchGroup.enter()
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("HealthKit error: \(error.localizedDescription)")
                }
                if let catSamples = samples?.compactMap({ $0 as? HKCategorySample }) {
                    allSamples.append(contentsOf: catSamples)
                }
                dispatchGroup.leave()
            }
            healthStore.execute(query)
        }

        dispatchGroup.notify(queue: .main) {
            guard !allSamples.isEmpty else {
                completion(nil)
                return
            }

            var uniqueSamples: [HKCategorySample] = []

            for sample in allSamples {
                let overlaps = uniqueSamples.firstIndex(where: {
                    ($0.startDate < sample.endDate) && (sample.startDate < $0.endDate)
                })

                if let idx = overlaps {
                    let existing = uniqueSamples[idx]
                    let newSource = sample.sourceRevision.source.name
                    let oldSource = existing.sourceRevision.source.name

                    if oldSource.contains("Watch") {
                        continue
                    } else if newSource.contains("Watch") {
                        uniqueSamples[idx] = sample
                    }
                } else {
                    uniqueSamples.append(sample)
                }
            }

            // Group samples into sessions based on gaps
            let sortedSamples = uniqueSamples.sorted(by: { $0.startDate < $1.startDate })
            var sessions: [[HKCategorySample]] = []
            var currentSession: [HKCategorySample] = []

            for sample in sortedSamples {
                if let last = currentSession.last {
                    let gap = sample.startDate.timeIntervalSince(last.endDate)
                    if gap > 7 * 3600 { // 7-hour gap between sessions - this is here to both separate nights and anticipate any naps
                        if !currentSession.isEmpty {
                            sessions.append(currentSession)
                        }
                        currentSession = [sample]
                    } else {
                        currentSession.append(sample)
                    }
                } else {
                    currentSession.append(sample)
                }
            }

            if !currentSession.isEmpty {
                sessions.append(currentSession)
            }

            // Find the most recent session with total sleep ≥ 3 hours - this is here to both separate nights and anticipate any naps
            let validSessions = sessions.compactMap { session -> (Double, Double, Date, Date, [String: Double])? in
                var asleepByType = [String: Double]()
                var totalAsleep: Double = 0.0
                var totalInBed: Double = 0.0

                for sample in session {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)

                    if let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        switch value {
                        case .inBed:
                            totalInBed += duration
                        case .asleepREM:
                            asleepByType["REM", default: 0.0] += duration
                            totalAsleep += duration
                        case .asleepCore:
                            asleepByType["Core", default: 0.0] += duration
                            totalAsleep += duration
                        case .asleepDeep:
                            asleepByType["Deep", default: 0.0] += duration
                            totalAsleep += duration
                        case .asleepUnspecified:
                            asleepByType["Unspecified", default: 0.0] += duration
                            totalAsleep += duration
                        default:
                            break
                        }
                    }
                }

                if totalAsleep >= 3 * 3600 {
                    let earliest = session.map(\.startDate).min() ?? session.first!.startDate
                    let latest = session.map(\.endDate).max() ?? session.last!.endDate
                    let sleepHoursByType = asleepByType.mapValues { $0 / 3600 }
                    return (totalAsleep / 3600, totalInBed / 3600, earliest, latest, sleepHoursByType)
                } else {
                    return nil
                }
            }

            if let best = validSessions.last {
                completion(best)
            } else {
                completion(nil)
            }
        }
    }

    /// Generic helper for fetching the latest quantity-based sample from HealthKit.
    ///
    /// - Parameters:
    ///   - type: The specific `HKQuantityType` to query.
    ///   - unit: The unit to use when interpreting the sample’s quantity.
    ///   - completion: Returns the latest value and its date, or `nil`.
    private func fetchLatestQuantitySample(for type: HKQuantityType, unit: HKUnit, completion: @escaping ((Double, Date)?) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                print("HealthKit error: \(error.localizedDescription)")
            }
            if let sample = samples?.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: unit)
                let date = sample.endDate
                completion((value, date))
            } else {
                completion(nil)
            }
        }
        healthStore.execute(query)
    }
    func fetchLatestWristTemperature(completion: @escaping ((Double, Date)?) -> Void) {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            completion(nil)
            return
        }
        fetchLatestQuantitySample(for: tempType, unit: HealthKitUnitCatalog.wristTemperature, completion: completion)
    }

    func fetchLatestOxygenSaturation(completion: @escaping ((Double, Date)?) -> Void) {
        guard let oxyType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion(nil)
            return
        }
        fetchLatestQuantitySample(for: oxyType, unit: HealthKitUnitCatalog.oxygenSaturation, completion: completion)
    }

    func fetchRecentWorkouts(completion: @escaping ([WorkoutSummary]) -> Void) {
        print("HK fetchRecentWorkouts query running…")
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 50, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            if let error = error {
                print("HealthKit error: \(error.localizedDescription)")
            }
            guard let workouts = samples?.compactMap({ $0 as? HKWorkout }), let self = self else {
                print("HK fetchRecentWorkouts completed with \(samples?.count ?? 0) HKWorkout samples")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            print("HK fetchRecentWorkouts completed with \(samples?.count ?? 0) HKWorkout samples")

            let group = DispatchGroup()
            var summaries: [WorkoutSummary] = []

            for workout in workouts {
                group.enter()
                if #available(iOS 18.0, *) {
                    self.fetchWorkoutEffortScore(for: workout) { rpe, rpeSource in
                        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                        let summary = WorkoutSummary(
                            id: workout.uuid,
                            date: workout.startDate,
                            type: workout.workoutActivityType,
                            duration: workout.duration,
                            energy: workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
                            rpe: rpe,
                            rpeSource: rpeSource
                        )
                        summaries.append(summary)
                        group.leave()
                    }
                } else {
                    let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                    let summary = WorkoutSummary(
                        id: workout.uuid,
                        date: workout.startDate,
                        type: workout.workoutActivityType,
                        duration: workout.duration,
                        energy: workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
                        rpe: nil,
                        rpeSource: nil
                    )
                    summaries.append(summary)
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion(summaries.sorted(by: { $0.date > $1.date }))
            }
        }
        print("HKManager: executing fetchRecentWorkouts query")
        healthStore.execute(query)
    }

    @available(iOS 18.0, *)
    private func fetchWorkoutEffortScore(for workout: HKWorkout, completion: @escaping (Double?, String?) -> Void) {
        guard let effortType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore),
              let estimatedType = HKQuantityType.quantityType(forIdentifier: .estimatedWorkoutEffortScore) else {
            completion(nil, nil)
            return
        }

        let dispatchGroup = DispatchGroup()
        var finalScore: Double?
        var scoreSource: String?

        func queryEffortScore(for type: HKQuantityType, handler: @escaping (Double?) -> Void) {
            let predicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: sort) { _, samples, error in
                if let error = error {
                    print("HealthKit error: \(error.localizedDescription)")
                }
                if let sample = samples?.first as? HKQuantitySample {
                    handler(sample.quantity.doubleValue(for: HKUnit.appleEffortScore()))
                } else {
                    handler(nil)
                }
            }
            healthStore.execute(query)
        }

        dispatchGroup.enter()
        queryEffortScore(for: effortType) { userScore in
            if let userScore = userScore {
                finalScore = userScore
                scoreSource = "User"
                dispatchGroup.leave()
            } else {
                queryEffortScore(for: estimatedType) { autoScore in
                    finalScore = autoScore
                    scoreSource = autoScore != nil ? "Estimated" : nil
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(finalScore, scoreSource)
        }
    }

    // Fetch total active energy burned in the last 24 hours
    func fetchActiveEnergyBurned(completion: @escaping ((Double, Date)?) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(nil)
            return
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("HealthKit error: \(error.localizedDescription)")
            }
            if let sum = result?.sumQuantity() {
                let value = sum.doubleValue(for: HealthKitUnitCatalog.activeEnergy)
                completion((value, endDate))
            } else {
                completion(nil)
            }
        }

        healthStore.execute(query)
    }

    // Fetch total mindful minutes in the last 24 hours
    func fetchMindfulMinutes(completion: @escaping ((Double, Date)?) -> Void) {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            completion(nil)
            return
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("HealthKit error: \(error.localizedDescription)")
            }
            let total = samples?.compactMap { $0 as? HKCategorySample }.reduce(0) {
                $0 + $1.endDate.timeIntervalSince($1.startDate)
            } ?? 0.0

            completion((total / 60, endDate)) // convert seconds to minutes
        }

        healthStore.execute(query)
    }

    // Calculate readiness score using input and baseline
    func calculateReadinessScore(with input: ReadinessInput, completion: @escaping (Int) -> Void) {
        Task {
            let baseline = await BaselineCalculator().calculateBaseline()
            let score = ReadinessCalculator().calculateScore(from: input, baseline: baseline)
            completion(score)
        }
    }
    // Fetch quantity samples for a given identifier and unit over the past N days
    func fetchQuantitySamples(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        pastDays: Int,
        completion: @escaping ([Double]) -> Void
    ) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion([])
            return
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -pastDays, to: endDate)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, results, error) in
            guard error == nil, let samples = results as? [HKQuantitySample] else {
                completion([])
                return
            }

            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            completion(values)
        }

        healthStore.execute(query)
    }
    /// Attempts to deep-link into the Fitness app to display this workout.
    func open(workout: WorkoutSummary) {
        // Construct the Health app URL for a specific workout by UUID
        let uuidString = workout.id.uuidString
        let urlString = "x-apple-health://workout/\(uuidString)"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("Cannot open Fitness app for workout \(uuidString)")
        }
    }
    // MARK: - Async/Await APIs

    /// Async version of `requestAuthorization(:_)`.
    ///
    /// - Throws: `HealthDataError.notAuthorized` if HealthKit authorization failed.
    ///
    /// ### Example
    /// ```swift
    /// let store = HealthDataStore.shared
    /// try await store.requestAuthorization()
    /// ```
    @available(iOS 13.0, *)
    public func requestAuthorization() async throws {
        let success = await withCheckedContinuation { continuation in
            self.requestAuthorization { success in
                continuation.resume(returning: success)
            }
        }
        if !success {
            throw HealthDataError.notAuthorized
        }
    }

    /// Async version of `fetchLatestHRV(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    ///
    /// ### Example
    /// ```swift
    /// let store = HealthDataStore.shared
    /// let (hrv, date) = try await store.fetchLatestHRV()
    /// ```
    @available(iOS 13.0, *)
    public func fetchLatestHRV() async throws -> (Double, Date) {
        try await fetchWithCache("fetchLatestHRV") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchLatestHRV { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchLatestRestingHR(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    public func fetchLatestRestingHR() async throws -> (Double, Date) {
        try await fetchWithCache("fetchLatestRestingHR") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchLatestRestingHR { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchLatestHRRecovery(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    public func fetchLatestHRRecovery() async throws -> (Double, Date) {
        try await fetchWithCache("fetchLatestHRRecovery") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchLatestHRRecovery { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchLatestRespiratoryRate(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    public func fetchLatestRespiratoryRate() async throws -> (Double, Date) {
        try await fetchWithCache("fetchLatestRespiratoryRate") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchLatestRespiratoryRate { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchLastNightSleep(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchLastNightSleep() async throws -> (Double, Double, Date, Date, [String: Double]) {
        try await fetchWithCache("fetchLastNightSleep") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchLastNightSleep { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchLatestWristTemperature(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchLatestWristTemperature() async throws -> (Double, Date) {
        try await fetchWithCache("fetchLatestWristTemperature") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchLatestWristTemperature { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchLatestOxygenSaturation(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchLatestOxygenSaturation() async throws -> (Double, Date) {
        try await fetchWithCache("fetchLatestOxygenSaturation") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchLatestOxygenSaturation { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchRecentWorkouts(:_)`.
    ///
    /// - Throws: Never (always returns, may be empty).
    @available(iOS 13.0, *)
    func fetchRecentWorkouts() async throws -> [WorkoutSummary] {
        try await fetchWithCache("fetchRecentWorkouts") { [unowned self] in
            await withCheckedContinuation { continuation in
                self.fetchRecentWorkouts { workouts in
                    continuation.resume(returning: workouts)
                }
            }
        }
    }

    /// Async version of `fetchActiveEnergyBurned(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchActiveEnergyBurned() async throws -> (Double, Date) {
        try await fetchWithCache("fetchActiveEnergyBurned") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchActiveEnergyBurned { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    /// Async version of `fetchMindfulMinutes(:_)`.
    ///
    /// - Throws: `HealthDataError.sampleUnavailable` if unavailable.
    @available(iOS 13.0, *)
    func fetchMindfulMinutes() async throws -> (Double, Date) {
        try await fetchWithCache("fetchMindfulMinutes") { [unowned self] in
            let result = await withCheckedContinuation { continuation in
                self.fetchMindfulMinutes { continuation.resume(returning: $0) }
            }
            guard let val = result else { throw HealthDataError.sampleUnavailable }
            return val
        }
    }

    

    /// Derive 1‑minute HRR for a specific workout (HR at end – HR 60s post).
    func deriveHRR(for workout: HKWorkout, completion: @escaping (Double?) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(nil); return
        }
        let windowStart = workout.endDate.addingTimeInterval(-120)
        let windowEnd   = workout.endDate.addingTimeInterval(180)
        let pred = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let q = HKSampleQuery(sampleType: hrType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let _ = self, let arr = samples as? [HKQuantitySample], !arr.isEmpty else { completion(nil); return }
            let unit = HealthKitUnitCatalog.heartRate
            let endHR = arr.min(by: { abs($0.endDate.timeIntervalSince(workout.endDate)) < abs($1.endDate.timeIntervalSince(workout.endDate)) })?.quantity.doubleValue(for: unit)
            let plus1m = workout.endDate.addingTimeInterval(60)
            let afterHR = arr.min(by: { abs($0.endDate.timeIntervalSince(plus1m)) < abs($1.endDate.timeIntervalSince(plus1m)) })?.quantity.doubleValue(for: unit)
            guard let endHR = endHR, let afterHR = afterHR else { completion(nil); return }
            completion(max(0, endHR - afterHR))
        }
        healthStore.execute(q)
    }

    @available(iOS 13.0, *)
    func deriveHRR(for workout: HKWorkout) async -> Double? {
        await withCheckedContinuation { cont in
            deriveHRR(for: workout) { cont.resume(returning: $0) }
        }
    }

    

    // MARK: - Workouts (HKWorkout) fetching for baseline calculations

    /// Fetches HKWorkout objects in the last `days` days.
    func fetchWorkouts(lastNDays days: Int, completion: @escaping ([HKWorkout]) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                print("HK fetchWorkouts error: \(error.localizedDescription)")
            }
            let workouts = (samples as? [HKWorkout]) ?? []
            DispatchQueue.main.async { completion(workouts) }
        }
        healthStore.execute(query)
    }

    @available(iOS 13.0, *)
    func fetchWorkouts(lastNDays days: Int) async -> [HKWorkout] {
        await withCheckedContinuation { cont in
            fetchWorkouts(lastNDays: days) { cont.resume(returning: $0) }
        }
    }
// MARK: - Async Streams

    /// Provides a continuous asynchronous stream of heart rate (BPM) samples.
    /// - Returns: An AsyncThrowingStream yielding (value, date) tuples as new samples arrive.
    ///
    /// ### Example
    /// ```swift
    /// let store = HealthDataStore.shared
    /// for try await (bpm, timestamp) in store.heartRateStream() {
    ///     print("HR: \(bpm) at \(timestamp)")
    /// }
    /// ```
    @available(iOS 13.0, *)
    public func heartRateStream() -> AsyncThrowingStream<(Double, Date), Error> {
        AsyncThrowingStream { continuation in
            guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                continuation.finish(throwing: HealthDataError.sampleUnavailable)
                return
            }
            let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
            let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { query, samples, _, _, error in
                if let error = error {
                    continuation.finish(throwing: HealthDataError.underlyingError(error))
                    return
                }
                let hrSamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                for sample in hrSamples {
                    let value = sample.quantity.doubleValue(for: HealthKitUnitCatalog.heartRate)
                    continuation.yield((value, sample.endDate))
                }
            }
            query.updateHandler = { _, samples, _, _, error in
                if let error = error {
                    continuation.finish(throwing: HealthDataError.underlyingError(error))
                    return
                }
                let hrSamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                for sample in hrSamples {
                    let value = sample.quantity.doubleValue(for: HealthKitUnitCatalog.heartRate)
                    continuation.yield((value, sample.endDate))
                }
            }
            healthStore.execute(query)
            continuation.onTermination = { @Sendable _ in
                self.healthStore.stop(query)
            }
        }
    }
}

// MARK: - HealthDataStoreProtocol Conformance
extension HealthDataStore: HealthDataStoreProtocol {}


    // MARK: - Authorization status helper (read permissions)
    /// Checks whether a HealthKit authorization request is needed for the app's read types.
    /// Uses `getRequestStatusForAuthorization` which reflects read permissions state.


// MARK: - Authorization status helper (read permissions)
extension HealthDataStore {
    /// Checks whether a HealthKit authorization request is needed for the app's read types.
    /// Uses `getRequestStatusForAuthorization` which reflects read permissions state.
    func getAuthorizationRequestStatus(completion: @escaping (HKAuthorizationRequestStatus) -> Void) {
        healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
            completion(status)
        }
    }
}
