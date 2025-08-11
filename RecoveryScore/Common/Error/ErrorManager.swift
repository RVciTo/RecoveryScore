///
/// ErrorManager.swift
/// RecoveryScore
///
/// Centralized error management system that handles error presentation,
/// recovery, and user interaction across the app.
///

import Foundation
import SwiftUI
import Combine

// MARK: - Error Manager Protocol

@MainActor
public protocol ErrorManaging: ObservableObject {
    /// Current error being displayed to user
    var currentError: RecoveryError? { get }
    /// Whether an error is currently being shown
    var isShowingError: Bool { get }
    /// Error history for debugging
    var errorHistory: [ErrorHistoryEntry] { get }
    
    /// Present an error to the user
    func handleError(_ error: RecoveryError, context: [String: Any]?)
    /// Dismiss the current error
    func dismissError()
    /// Retry the last failed operation
    func retryLastOperation()
    /// Clear error history
    func clearHistory()
}

// MARK: - Error History Entry

public struct ErrorHistoryEntry: Identifiable {
    public let id = UUID()
    public let error: RecoveryError
    public let timestamp: Date
    public let context: [String: Any]?
    public let wasRetried: Bool
    public let wasResolved: Bool
    
    public init(
        error: RecoveryError,
        context: [String: Any]? = nil,
        wasRetried: Bool = false,
        wasResolved: Bool = false
    ) {
        self.error = error
        self.timestamp = Date()
        self.context = context
        self.wasRetried = wasRetried
        self.wasResolved = wasResolved
    }
}

// MARK: - Error Manager Implementation

@MainActor
public final class ErrorManager: ErrorManaging {
    
    // MARK: - Singleton
    
    public static let shared = ErrorManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentError: RecoveryError?
    @Published public private(set) var isShowingError: Bool = false
    @Published public private(set) var errorHistory: [ErrorHistoryEntry] = []
    
    // MARK: - Private Properties
    
    private var retryOperation: (() -> Void)?
    private var errorDismissalTimer: Timer?
    private let maxHistoryCount = 50
    
    // Configuration
    private let autoDismissDelay: TimeInterval = 5.0
    private let enableAutoDismiss: Bool
    private let enableRetryMechanism: Bool
    
    // MARK: - Initialization
    
    public init(
        enableAutoDismiss: Bool = true,
        enableRetryMechanism: Bool = true
    ) {
        self.enableAutoDismiss = enableAutoDismiss
        self.enableRetryMechanism = enableRetryMechanism
    }
    
    // MARK: - Public Methods
    
    public func handleError(_ error: RecoveryError, context: [String: Any]? = nil) {
        // Log the error
        ErrorLogger.shared.log(error, context: context)
        
        // Add to history
        let historyEntry = ErrorHistoryEntry(error: error, context: context)
        addToHistory(historyEntry)
        
        // Update UI state
        currentError = error
        isShowingError = true
        
        // Setup auto-dismissal for non-critical errors
        if enableAutoDismiss && error.severity != .critical {
            scheduleAutoDismissal()
        }
        
        // Handle specific error types
        handleSpecificError(error, context: context)
    }
    
    public func handleError(_ error: RecoveryError, retryOperation: @escaping () -> Void) {
        self.retryOperation = retryOperation
        handleError(error, context: nil)
    }
    
    public func dismissError() {
        cancelAutoDismissal()
        currentError = nil
        isShowingError = false
        retryOperation = nil
    }
    
    public func retryLastOperation() {
        guard let operation = retryOperation,
              let error = currentError,
              error.isRetryable else {
            return
        }
        
        // Mark as retried in history
        updateLastHistoryEntry(wasRetried: true)
        
        // Log retry attempt
        ErrorLogger.shared.info(
            "Retrying operation after error: \(error.code)",
            category: .system,
            context: ["retry_count": 1]
        )
        
        dismissError()
        operation()
    }
    
    public func clearHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func addToHistory(_ entry: ErrorHistoryEntry) {
        errorHistory.append(entry)
        
        // Limit history size
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeFirst(errorHistory.count - maxHistoryCount)
        }
    }
    
    private func updateLastHistoryEntry(wasRetried: Bool = false, wasResolved: Bool = false) {
        guard !errorHistory.isEmpty else { return }
        
        let lastEntry = errorHistory.removeLast()
        let updatedEntry = ErrorHistoryEntry(
            error: lastEntry.error,
            context: lastEntry.context,
            wasRetried: wasRetried || lastEntry.wasRetried,
            wasResolved: wasResolved || lastEntry.wasResolved
        )
        errorHistory.append(updatedEntry)
    }
    
    private func scheduleAutoDismissal() {
        cancelAutoDismissal()
        
        errorDismissalTimer = Timer.scheduledTimer(withTimeInterval: autoDismissDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissError()
            }
        }
    }
    
    private func cancelAutoDismissal() {
        errorDismissalTimer?.invalidate()
        errorDismissalTimer = nil
    }
    
    private func handleSpecificError(_ error: RecoveryError, context: [String: Any]?) {
        switch error {
        case let healthError as HealthDataError:
            handleHealthDataError(healthError, context: context)
        case let calcError as CalculationError:
            handleCalculationError(calcError, context: context)
        case let systemError as SystemError:
            handleSystemError(systemError, context: context)
        default:
            // Generic error handling
            break
        }
    }
    
    private func handleHealthDataError(_ error: HealthDataError, context: [String: Any]?) {
        switch error {
        case .notAuthorized, .permissionDenied:
            // Could trigger permission request flow
            ErrorLogger.shared.info("Health permission error detected", category: .healthData)
            
        case .deviceNotAvailable:
            // Could show device connection guidance
            ErrorLogger.shared.info("Device availability issue", category: .healthData)
            
        case .queryTimeout:
            // Automatically retry after delay
            if enableRetryMechanism {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.retryLastOperation()
                }
            }
            
        default:
            break
        }
    }
    
    private func handleCalculationError(_ error: CalculationError, context: [String: Any]?) {
        switch error {
        case .missingRequiredData:
            // Could trigger data collection guidance
            ErrorLogger.shared.warning("Missing required data for calculations", category: .calculation)
            
        case .baselineCalculationFailed, .scoreCalculationFailed:
            // Could trigger algorithm fallback
            ErrorLogger.shared.error("Calculation algorithm failed", category: .calculation, context: context)
            
        default:
            break
        }
    }
    
    private func handleSystemError(_ error: SystemError, context: [String: Any]?) {
        switch error {
        case .memoryPressure:
            // Could trigger memory cleanup
            ErrorLogger.shared.warning("Memory pressure detected", category: .system)
            
        case .diskSpaceLow:
            // Could trigger cleanup suggestions
            ErrorLogger.shared.warning("Low disk space", category: .system)
            
        case .backgroundTaskTimeout:
            // Could reschedule background tasks
            ErrorLogger.shared.info("Background task timeout", category: .system)
            
        default:
            break
        }
    }
}

// MARK: - Error Presentation Helpers

public extension ErrorManager {
    
    /// Get user-friendly error presentation data
    func getCurrentErrorPresentation() -> ErrorPresentation? {
        guard let error = currentError else { return nil }
        
        let summary = error.userSummary()
        return ErrorPresentation(
            title: summary.title,
            message: summary.message,
            severity: error.severity,
            actions: summary.actions,
            isRetryable: error.isRetryable && retryOperation != nil,
            isDismissable: true
        )
    }
    
    /// Check if there are any critical errors in history
    var hasCriticalErrors: Bool {
        return errorHistory.contains { $0.error.severity == .critical }
    }
    
    /// Get count of errors by severity
    func errorCount(for severity: ErrorSeverity) -> Int {
        return errorHistory.filter { $0.error.severity == severity }.count
    }
    
    /// Get most recent errors of a specific type
    func recentErrors<T: RecoveryError>(ofType type: T.Type, limit: Int = 10) -> [ErrorHistoryEntry] {
        return Array(errorHistory
            .filter { $0.error is T }
            .suffix(limit)
        )
    }
}

// MARK: - Error Presentation Model

public struct ErrorPresentation {
    public let title: String
    public let message: String
    public let severity: ErrorSeverity
    public let actions: [String]
    public let isRetryable: Bool
    public let isDismissable: Bool
    
    public var alertStyle: AlertStyle {
        switch severity {
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
}

// MARK: - Alert Style

public enum AlertStyle {
    case info
    case warning
    case error
    case critical
    
    public var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    public var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Convenience Functions

/// Global error handling function
public func handleError(_ error: RecoveryError, context: [String: Any]? = nil) {
    Task { @MainActor in
        ErrorManager.shared.handleError(error, context: context)
    }
}

/// Global error handling with retry
public func handleError(_ error: RecoveryError, retry: @escaping () -> Void) {
    Task { @MainActor in
        ErrorManager.shared.handleError(error, retryOperation: retry)
    }
}