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
          ///
          /// - Returns: A `RecoveryDataBundle` containing the most recent biometric values and baselines.
          public func fetchRecoveryData() async -> RecoveryDataBundle {
              async let hrv = fetchLatest(healthStore.fetchLatestHRV)
              async let rhr = fetchLatest(healthStore.fetchLatestRestingHR)
              async let hrr = fetchLatest(healthStore.fetchLatestHRRecovery)
              async let resp = fetchLatest(healthStore.fetchLatestRespiratoryRate)
              async let temp = fetchLatest(healthStore.fetchLatestWristTemperature)
              async let o2 = fetchLatest(healthStore.fetchLatestOxygenSaturation)
              async let energy = fetchLatest(healthStore.fetchActiveEnergyBurned)
              async let mindful = fetchLatest(healthStore.fetchMindfulMinutes)
              async let sleep = fetchLatest(healthStore.fetchLastNightSleep)
              async let baseline = baselineCalculator.calculateBaseline()

              return await RecoveryDataBundle(
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
