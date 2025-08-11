///
/// DependencyContainer.swift
/// RecoveryScore
///
/// Centralized dependency injection container for the app.
/// Provides clean separation of dependencies and improves testability.
///

import Foundation

/// Protocol defining the dependency container interface
public protocol DependencyContainerProtocol {
    func makeHealthDataStore() -> HealthDataStore
    func makeBaselineCalculator() -> BaselineCalculatorProtocol
    func makeRecoveryDataService() -> RecoveryDataServicing
    @MainActor func makeRecoveryBiometricsViewModel() -> RecoveryBiometricsViewModel
}

/// Main dependency injection container for the app
public final class DependencyContainer: DependencyContainerProtocol {
    
    // MARK: - Singleton
    public static let shared = DependencyContainer()
    private init() {}
    
    // MARK: - Cached instances
    private lazy var _healthDataStore = HealthDataStore.shared
    private lazy var _baselineCalculator = BaselineCalculator(healthDataStore: _healthDataStore)
    private lazy var _recoveryDataService = RecoveryDataService(
        healthStore: _healthDataStore,
        baselineCalculator: _baselineCalculator
    )
    
    // MARK: - Factory Methods
    
    public func makeHealthDataStore() -> HealthDataStore {
        return _healthDataStore
    }
    
    public func makeBaselineCalculator() -> BaselineCalculatorProtocol {
        return _baselineCalculator
    }
    
    public func makeRecoveryDataService() -> RecoveryDataServicing {
        return _recoveryDataService
    }
    
    @MainActor
    public func makeRecoveryBiometricsViewModel() -> RecoveryBiometricsViewModel {
        return RecoveryBiometricsViewModel(service: _recoveryDataService)
    }
}

/// Test-specific dependency container for mocking
final class TestDependencyContainer: DependencyContainerProtocol {
    
    var mockHealthDataStore: HealthDataStore?
    var mockBaselineCalculator: BaselineCalculatorProtocol?
    var mockRecoveryDataService: RecoveryDataServicing?
    
    func makeHealthDataStore() -> HealthDataStore {
        return mockHealthDataStore ?? HealthDataStore.shared
    }
    
    func makeBaselineCalculator() -> BaselineCalculatorProtocol {
        return mockBaselineCalculator ?? BaselineCalculator(healthDataStore: makeHealthDataStore())
    }
    
    func makeRecoveryDataService() -> RecoveryDataServicing {
        return mockRecoveryDataService ?? RecoveryDataService(
            healthStore: makeHealthDataStore(),
            baselineCalculator: makeBaselineCalculator()
        )
    }
    
    @MainActor
    func makeRecoveryBiometricsViewModel() -> RecoveryBiometricsViewModel {
        return RecoveryBiometricsViewModel(service: makeRecoveryDataService())
    }
}