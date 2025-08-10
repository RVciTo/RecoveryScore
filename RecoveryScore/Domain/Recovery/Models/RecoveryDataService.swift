/// RecoveryDataService.swift
      /// Provides a unified interface for fetching recent recovery metrics and baselines.
      ///
      /// This is a domain-layer service, responsible for aggregating all biometric values
      /// required by the recovery and readiness logic.

      import Foundation
      import HealthKit

      /// Holds all metrics required to compute a readiness score.
      struct RecoveryDataBundle {
          let hrv: (Double, Date)?
          let rhr: (Double, Date)?
          let hrr: (Double, Date)?
          let respiratoryRate: (Double, Date)?
          let wristTemp: (Double, Date)?
          let oxygenSaturation: (Double, Date)?
          let activeEnergyBurned: (Double, Date)?
          let mindfulMinutes: (Double, Date)?
          let sleepInfo: (Double, Double, Date, Date, [String: Double])?
          let baseline: BaselineData
      }

      /// Service responsible for gathering recovery-related metrics from HealthKit.
      struct RecoveryDataService {

          let healthStore: HealthDataStore

          /// Initializes the service with a custom or shared HealthDataStore.
          ///
          /// - Parameter healthStore: The health data source (default is shared singleton).
          init(healthStore: HealthDataStore = .shared) {
              self.healthStore = healthStore
          }

          /// Fetches the full recovery data bundle: all metrics and baseline values.
          ///
          /// - Returns: A `RecoveryDataBundle` containing the most recent biometric values and baselines.
          func fetchRecoveryData() async -> RecoveryDataBundle {
              async let hrv = fetchLatest(healthStore.fetchLatestHRV)
              async let rhr = fetchLatest(healthStore.fetchLatestRestingHR)
              async let hrr = fetchLatest(healthStore.fetchLatestHRRecovery)
              async let resp = fetchLatest(healthStore.fetchLatestRespiratoryRate)
              async let temp = fetchLatest(healthStore.fetchLatestWristTemperature)
              async let o2 = fetchLatest(healthStore.fetchLatestOxygenSaturation)
              async let energy = fetchLatest(healthStore.fetchActiveEnergyBurned)
              async let mindful = fetchLatest(healthStore.fetchMindfulMinutes)
              async let sleep = fetchLatest(healthStore.fetchLastNightSleep)
              async let baseline = BaselineCalculator().calculateBaseline()

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
