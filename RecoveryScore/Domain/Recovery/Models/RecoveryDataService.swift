/// RecoveryDataService.swift
      /// Provides a unified interface for fetching recent recovery metrics and baselines.
      ///
      /// This is a domain-layer service, responsible for aggregating all biometric values
      /// required by the recovery and readiness logic.

      import Foundation
      import HealthKit

/// Lightweight protocol so the ViewModel can be tested with a mock service.
public protocol RecoveryDataServicing {
    func fetchRecoveryData() async -> RecoveryDataBundle
}

extension RecoveryDataService: RecoveryDataServicing {}


      /// Holds all metrics required to compute a readiness score.
      public struct RecoveryDataBundle {
          public let hrv: (Double, Date)?
          public let rhr: (Double, Date)?
          public let hrr: (Double, Date)?
          public let respiratoryRate: (Double, Date)?
          public let wristTemp: (Double, Date)?
          public let oxygenSaturation: (Double, Date)?
          public let activeEnergyBurned: (Double, Date)?
          public let mindfulMinutes: (Double, Date)?
          public let sleepInfo: (Double, Double, Date, Date, [String: Double])?
          public let baseline: BaselineData
          
          public init(hrv: (Double, Date)?, rhr: (Double, Date)?, hrr: (Double, Date)?, respiratoryRate: (Double, Date)?, wristTemp: (Double, Date)?, oxygenSaturation: (Double, Date)?, activeEnergyBurned: (Double, Date)?, mindfulMinutes: (Double, Date)?, sleepInfo: (Double, Double, Date, Date, [String: Double])?, baseline: BaselineData) {
              self.hrv = hrv
              self.rhr = rhr
              self.hrr = hrr
              self.respiratoryRate = respiratoryRate
              self.wristTemp = wristTemp
              self.oxygenSaturation = oxygenSaturation
              self.activeEnergyBurned = activeEnergyBurned
              self.mindfulMinutes = mindfulMinutes
              self.sleepInfo = sleepInfo
              self.baseline = baseline
          }
      }

      /// Service responsible for gathering recovery-related metrics from HealthKit.
      public struct RecoveryDataService {

          let healthStore: HealthDataStore
          let baselineCalculator: BaselineCalculatorProtocol

          /// Initializes the service with custom dependencies.
          ///
          /// - Parameters:
          ///   - healthStore: The health data source (default is shared singleton).
          ///   - baselineCalculator: The baseline calculator for computing averages.
          public init(
              healthStore: HealthDataStore = .shared,
              baselineCalculator: BaselineCalculatorProtocol = BaselineCalculator()
          ) {
              self.healthStore = healthStore
              self.baselineCalculator = baselineCalculator
          }

          /// Fetches the full recovery data bundle: all metrics and baseline values.
          /// Uses improved error handling to distinguish between different failure types.
          ///
          /// - Returns: A `RecoveryDataBundle` containing the most recent biometric values and baselines.
          /// - Note: Individual metric failures are logged but don't prevent bundle creation.
          public func fetchRecoveryData() async -> RecoveryDataBundle {
              ErrorLogger.shared.debug("Starting recovery data fetch", category: .healthData)
              
              // Fetch all metrics concurrently with proper error handling
              let hrvTask = Task { await fetchLatestWithErrorHandling("HRV") { try await healthStore.fetchLatestHRV() } }
              let rhrTask = Task { await fetchLatestWithErrorHandling("Resting HR") { try await healthStore.fetchLatestRestingHR() } }
              let hrrTask = Task { await fetchLatestWithErrorHandling("HR Recovery") { try await healthStore.fetchLatestHRRecovery() } }
              let respTask = Task { await fetchLatestWithErrorHandling("Respiratory Rate") { try await healthStore.fetchLatestRespiratoryRate() } }
              let tempTask = Task { await fetchLatestWithErrorHandling("Wrist Temperature") { try await fetchWristTemperature() } }
              let o2Task = Task { await fetchLatestWithErrorHandling("Oxygen Saturation") { try await fetchOxygenSaturation() } }
              let energyTask = Task { await fetchLatestWithErrorHandling("Active Energy") { try await fetchActiveEnergy() } }
              let mindfulTask = Task { await fetchLatestWithErrorHandling("Mindful Minutes") { try await fetchMindfulMinutes() } }
              let sleepTask = Task { await fetchLatestWithErrorHandling("Sleep Info") { try await fetchSleepInfo() } }
              
              // Handle baseline calculation separately with error handling
              let baseline = await fetchBaselineWithErrorHandling()

              let hrv = await hrvTask.value
              let rhr = await rhrTask.value
              let hrr = await hrrTask.value
              let resp = await respTask.value
              let temp = await tempTask.value
              let o2 = await o2Task.value
              let energy = await energyTask.value
              let mindful = await mindfulTask.value
              let sleep = await sleepTask.value

              let bundle = RecoveryDataBundle(
                  hrv: hrv,
                  rhr: rhr,
                  hrr: hrr,
                  respiratoryRate: resp,
                  wristTemp: temp,
                  oxygenSaturation: o2,
                  activeEnergyBurned: energy,
                  mindfulMinutes: mindful,
                  sleepInfo: sleep,
                  baseline: baseline
              )
              
              ErrorLogger.shared.info(
                  "Recovery data fetch completed",
                  category: .healthData,
                  context: [
                      "hrv_available": hrv != nil,
                      "rhr_available": rhr != nil,
                      "hrr_available": hrr != nil,
                      "total_metrics": 9
                  ]
              )
              
              return bundle
          }
          
          /// Fetches individual metrics with comprehensive error handling and logging.
          private func fetchLatestWithErrorHandling<T>(
              _ metricName: String,
              fetcher: @escaping () async throws -> T
          ) async -> T? {
              do {
                  let result = try await fetcher()
                  ErrorLogger.shared.debug(
                      "Successfully fetched \(metricName)",
                      category: .healthData
                  )
                  return result
              } catch let error as RecoveryError {
                  // Log specific health data errors but don't propagate
                  ErrorLogger.shared.log(
                      error,
                      context: [
                          "metric": metricName,
                          "operation": "fetch",
                          "error_severity": error.severity.rawValue
                      ]
                  )
                  return nil
              } catch {
                  // Handle unexpected errors
                  let wrappedError = HealthDataError.underlyingError(error)
                  ErrorLogger.shared.log(
                      wrappedError,
                      context: [
                          "metric": metricName,
                          "operation": "fetch",
                          "unexpected_error": true
                      ]
                  )
                  return nil
              }
          }
          
          /// Handle baseline calculation with error recovery
          private func fetchBaselineWithErrorHandling() async -> BaselineData {
              let baseline = await baselineCalculator.calculateBaseline()
              ErrorLogger.shared.debug("Baseline calculation successful", category: .calculation)
              return baseline
          }
          
          // Legacy compatibility wrapper methods - return values directly
          private func fetchWristTemperature() async throws -> (Double, Date) {
              return try await withCheckedThrowingContinuation { continuation in
                  healthStore.fetchLatestWristTemperature { result in
                      if let result = result {
                          continuation.resume(returning: result)
                      } else {
                          continuation.resume(throwing: RecoveryScore.HealthDataError.dataUnavailable(metric: "Wrist Temperature", timeRange: "latest"))
                      }
                  }
              }
          }
          
          private func fetchOxygenSaturation() async throws -> (Double, Date) {
              return try await withCheckedThrowingContinuation { continuation in
                  healthStore.fetchLatestOxygenSaturation { result in
                      if let result = result {
                          continuation.resume(returning: result)
                      } else {
                          continuation.resume(throwing: RecoveryScore.HealthDataError.dataUnavailable(metric: "Oxygen Saturation", timeRange: "latest"))
                      }
                  }
              }
          }
          
          private func fetchActiveEnergy() async throws -> (Double, Date) {
              return try await withCheckedThrowingContinuation { continuation in
                  healthStore.fetchActiveEnergyBurned { result in
                      if let result = result {
                          continuation.resume(returning: result)
                      } else {
                          continuation.resume(throwing: RecoveryScore.HealthDataError.dataUnavailable(metric: "Active Energy", timeRange: "latest"))
                      }
                  }
              }
          }
          
          private func fetchMindfulMinutes() async throws -> (Double, Date) {
              return try await withCheckedThrowingContinuation { continuation in
                  healthStore.fetchMindfulMinutes { result in
                      if let result = result {
                          continuation.resume(returning: result)
                      } else {
                          continuation.resume(throwing: RecoveryScore.HealthDataError.dataUnavailable(metric: "Mindful Minutes", timeRange: "latest"))
                      }
                  }
              }
          }
          
          private func fetchSleepInfo() async throws -> (Double, Double, Date, Date, [String: Double]) {
              return try await withCheckedThrowingContinuation { continuation in
                  healthStore.fetchLastNightSleep { result in
                      if let result = result {
                          continuation.resume(returning: result)
                      } else {
                          continuation.resume(throwing: RecoveryScore.HealthDataError.dataUnavailable(metric: "Sleep Info", timeRange: "last night"))
                      }
                  }
              }
          }

          /// Wraps a callback-based fetch method into an `async` interface.
          ///
          /// - Parameter fetcher: A function that takes a completion block returning `T?`.
          /// - Returns: The result `T?`, asynchronously.
          private func fetchLatest<T>(_ fetcher: @escaping (@escaping (T?) -> Void) -> Void) async -> T? {
              await withCheckedContinuation { continuation in
                  fetcher { value in
                      continuation.resume(returning: value)
                  }
              }
          }
      }
