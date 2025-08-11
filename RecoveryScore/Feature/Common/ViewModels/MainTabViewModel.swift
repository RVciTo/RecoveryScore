//
//  MainTabViewModel.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 01/08/2025.
//


/// MainTabViewModel.swift
/// Manages tab selection and health metric state for MainTabView

import Foundation
import Combine
import HealthKit

@MainActor
public class MainTabViewModel: ObservableObject {
    // MARK: - Tab Selection
    public enum Tab: Hashable { case dashboard, settings }

    @Published public var selectedTab: Tab = .dashboard

    // MARK: - Health Metrics State
    @Published public var hrv: (Double, Date)?
    @Published public var rhr: (Double, Date)?
    @Published public var hrr: (Double, Date)?
    @Published public var respiratoryRate: (Double, Date)?
    @Published public var wristTemp: (Double, Date)?
    @Published public var oxygenSaturation: (Double, Date)?
    @Published public var sleepInfo: (Double, Double, Date, Date, [String: Double])?

    @Published public var activeEnergyBurned: (Double, Date)?
    @Published public var mindfulMinutes: (Double, Date)?

    @Published public var readinessScore: Int?
    @Published public var showReadinessExplanation: Bool = false

    // MARK: - Baselines
    @Published public var hrvBaseline: Double?
    @Published public var rhrBaseline: Double?
    @Published public var hrrBaseline: Double?
    @Published public var respiratoryBaseline: Double?
    @Published public var wristTempBaseline: Double?

    // MARK: - HealthKit Auth State
    @Published public var isAuthorized: Bool = false

    // MARK: - Dependencies & Helpers
    private let healthStore = HealthDataStore.shared
    private var cancellables = Set<AnyCancellable>()
    private let dependencyContainer: DependencyContainerProtocol

    // Nested ViewModels
    let recoveryBiometricsViewModel: RecoveryBiometricsViewModel

    public init(dependencyContainer: DependencyContainerProtocol = DependencyContainer.shared) {
        self.dependencyContainer = dependencyContainer
        self.recoveryBiometricsViewModel = dependencyContainer.makeRecoveryBiometricsViewModel()
    }

    public func requestHealthKitAuthorization() {
        healthStore.requestAuthorization { success in
            DispatchQueue.main.async {
                self.isAuthorized = success
                // CRITICAL: Also update the nested view model's authorization state
                self.recoveryBiometricsViewModel.isAuthorized = success
            }
            if success {
                self.fetchMetrics()
            }
        }
    }

    private func fetchMetrics() {
        // Note: Full metric fetching is handled by RecoveryBiometricsViewModel
        // This is a minimal example for authorization flow validation
        healthStore.fetchQuantitySamples(identifier: .heartRateVariabilitySDNN,
                                         unit: .secondUnit(with: .milli),
                                         pastDays: 1) { values in
            DispatchQueue.main.async {
                let total = values.reduce(0, +)
                self.hrv = (total, Date())
            }
        }
    }
}
