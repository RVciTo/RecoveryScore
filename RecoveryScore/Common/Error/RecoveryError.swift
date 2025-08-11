///
/// RecoveryError.swift
/// RecoveryScore
///
/// Comprehensive error management system for the RecoveryScore app.
/// Provides structured error handling across all architectural layers.
///

import Foundation
import HealthKit

// MARK: - Core Error Protocol

/// Protocol for all RecoveryScore application errors
public protocol RecoveryError: Error, LocalizedError {
    /// Unique error code for programmatic handling
    var code: String { get }
    /// User-friendly error title
    var title: String { get }
    /// Detailed error description for users
    var message: String { get }
    /// Suggested user actions to resolve the error
    var userActions: [String] { get }
    /// Error severity level
    var severity: ErrorSeverity { get }
    /// Whether this error can be retried
    var isRetryable: Bool { get }
    /// Underlying system error if available
    var underlyingError: Error? { get }
}

// MARK: - Error Severity

public enum ErrorSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning" 
    case error = "error"
    case critical = "critical"
    
    public var priority: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        case .critical: return 3
        }
    }
}

// MARK: - Health Data Errors

public enum HealthDataError: RecoveryError {
    case notAuthorized(requestedTypes: [HKObjectType])
    case permissionDenied(metric: String)
    case deviceNotAvailable(metric: String)
    case dataUnavailable(metric: String, timeRange: String)
    case healthKitUnavailable
    case backgroundDeliveryFailed(metric: String)
    case queryTimeout(metric: String)
    case dataCorrupted(metric: String, details: String)
    case rateLimitExceeded
    case underlyingError(Error)
    
    public var code: String {
        switch self {
        case .notAuthorized: return "health.not_authorized"
        case .permissionDenied: return "health.permission_denied"
        case .deviceNotAvailable: return "health.device_unavailable"
        case .dataUnavailable: return "health.data_unavailable"
        case .healthKitUnavailable: return "health.healthkit_unavailable"
        case .backgroundDeliveryFailed: return "health.background_delivery_failed"
        case .queryTimeout: return "health.query_timeout"
        case .dataCorrupted: return "health.data_corrupted"
        case .rateLimitExceeded: return "health.rate_limit_exceeded"
        case .underlyingError: return "health.underlying_error"
        }
    }
    
    public var title: String {
        switch self {
        case .notAuthorized: return "Health Data Access Required"
        case .permissionDenied: return "Permission Denied"
        case .deviceNotAvailable: return "Device Required"
        case .dataUnavailable: return "Data Not Available"
        case .healthKitUnavailable: return "HealthKit Unavailable"
        case .backgroundDeliveryFailed: return "Background Update Failed"
        case .queryTimeout: return "Data Load Timeout"
        case .dataCorrupted: return "Data Error"
        case .rateLimitExceeded: return "Too Many Requests"
        case .underlyingError: return "Health Data Error"
        }
    }
    
    public var message: String {
        switch self {
        case .notAuthorized(let types):
            return "Please grant access to health data types: \(types.map { $0.identifier }.joined(separator: ", "))"
        case .permissionDenied(let metric):
            return "Access to \(metric) data has been denied. Please enable in Settings > Health > Data Access & Devices."
        case .deviceNotAvailable(let metric):
            return "Apple Watch is required to measure \(metric). Please wear your watch and try again."
        case .dataUnavailable(let metric, let timeRange):
            return "No \(metric) data available for \(timeRange). Please wear your Apple Watch regularly."
        case .healthKitUnavailable:
            return "HealthKit is not available on this device. Health data features cannot be used."
        case .backgroundDeliveryFailed(let metric):
            return "Failed to set up automatic updates for \(metric). Manual refresh may be required."
        case .queryTimeout(let metric):
            return "Loading \(metric) data is taking too long. Please check your connection and try again."
        case .dataCorrupted(let metric, let details):
            return "\(metric) data appears corrupted: \(details). Please contact support."
        case .rateLimitExceeded:
            return "Too many health data requests. Please wait a moment before trying again."
        case .underlyingError(let error):
            return "Health data error: \(error.localizedDescription)"
        }
    }
    
    public var userActions: [String] {
        switch self {
        case .notAuthorized, .permissionDenied:
            return ["Open Settings", "Go to Health > Data Access & Devices", "Enable RecoveryScore permissions"]
        case .deviceNotAvailable:
            return ["Wear your Apple Watch", "Ensure watch is connected", "Wait for data sync"]
        case .dataUnavailable:
            return ["Wear Apple Watch regularly", "Wait for more data", "Check watch connection"]
        case .healthKitUnavailable:
            return ["Use device that supports HealthKit", "Contact support if issue persists"]
        case .backgroundDeliveryFailed:
            return ["Restart app", "Check app permissions", "Contact support"]
        case .queryTimeout:
            return ["Check network connection", "Retry in a moment", "Restart app if needed"]
        case .dataCorrupted:
            return ["Restart app", "Reinstall app if needed", "Contact support"]
        case .rateLimitExceeded:
            return ["Wait 30 seconds", "Retry operation", "Avoid rapid requests"]
        case .underlyingError:
            return ["Restart app", "Check system status", "Contact support if persistent"]
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .notAuthorized, .permissionDenied: return .error
        case .deviceNotAvailable, .dataUnavailable: return .warning
        case .healthKitUnavailable, .dataCorrupted: return .critical
        case .backgroundDeliveryFailed: return .warning
        case .queryTimeout, .rateLimitExceeded: return .error
        case .underlyingError: return .error
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .notAuthorized, .permissionDenied, .healthKitUnavailable: return false
        case .deviceNotAvailable, .dataUnavailable: return true
        case .backgroundDeliveryFailed, .queryTimeout, .rateLimitExceeded: return true
        case .dataCorrupted: return false
        case .underlyingError: return true
        }
    }
    
    public var underlyingError: Error? {
        switch self {
        case .underlyingError(let error): return error
        default: return nil
        }
    }
}

// MARK: - Calculation Errors

public enum CalculationError: RecoveryError {
    case invalidInput(parameter: String, value: Any?)
    case missingRequiredData(metrics: [String])
    case baselineCalculationFailed(reason: String)
    case scoreCalculationFailed(algorithm: String, reason: String)
    case algorithmError(name: String, details: String)
    case dataValidationFailed(field: String, constraints: String)
    
    public var code: String {
        switch self {
        case .invalidInput: return "calc.invalid_input"
        case .missingRequiredData: return "calc.missing_required_data"
        case .baselineCalculationFailed: return "calc.baseline_failed"
        case .scoreCalculationFailed: return "calc.score_failed"
        case .algorithmError: return "calc.algorithm_error"
        case .dataValidationFailed: return "calc.validation_failed"
        }
    }
    
    public var title: String {
        switch self {
        case .invalidInput: return "Invalid Data"
        case .missingRequiredData: return "Required Data Missing"
        case .baselineCalculationFailed: return "Baseline Calculation Failed"
        case .scoreCalculationFailed: return "Score Calculation Failed"
        case .algorithmError: return "Calculation Error"
        case .dataValidationFailed: return "Data Validation Failed"
        }
    }
    
    public var message: String {
        switch self {
        case .invalidInput(let parameter, let value):
            return "Invalid value for \(parameter): \(value ?? "nil")"
        case .missingRequiredData(let metrics):
            return "Missing required metrics: \(metrics.joined(separator: ", "))"
        case .baselineCalculationFailed(let reason):
            return "Failed to calculate personal baselines: \(reason)"
        case .scoreCalculationFailed(let algorithm, let reason):
            return "Failed to calculate \(algorithm) score: \(reason)"
        case .algorithmError(let name, let details):
            return "Error in \(name) algorithm: \(details)"
        case .dataValidationFailed(let field, let constraints):
            return "\(field) validation failed: \(constraints)"
        }
    }
    
    public var userActions: [String] {
        switch self {
        case .invalidInput, .dataValidationFailed:
            return ["Check data quality", "Restart app", "Contact support if persistent"]
        case .missingRequiredData:
            return ["Ensure Apple Watch is worn", "Grant health permissions", "Wait for more data"]
        case .baselineCalculationFailed:
            return ["Wear watch for 7+ days", "Ensure consistent data", "Contact support"]
        case .scoreCalculationFailed, .algorithmError:
            return ["Restart app", "Update app", "Contact support with error details"]
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .invalidInput, .dataValidationFailed: return .warning
        case .missingRequiredData: return .warning
        case .baselineCalculationFailed: return .error
        case .scoreCalculationFailed, .algorithmError: return .error
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .invalidInput, .dataValidationFailed: return false
        case .missingRequiredData: return true
        case .baselineCalculationFailed, .scoreCalculationFailed: return true
        case .algorithmError: return false
        }
    }
    
    public var underlyingError: Error? {
        return nil
    }
}

// MARK: - System Errors

public enum SystemError: RecoveryError {
    case diskSpaceLow
    case memoryPressure
    case backgroundTaskTimeout
    case userDefaultsCorrupted(key: String)
    case fileSystemError(operation: String, path: String)
    case networkNotAvailable
    case unsupportedDevice
    case osVersionNotSupported(required: String, current: String)
    
    public var code: String {
        switch self {
        case .diskSpaceLow: return "system.disk_space_low"
        case .memoryPressure: return "system.memory_pressure"
        case .backgroundTaskTimeout: return "system.background_timeout"
        case .userDefaultsCorrupted: return "system.userdefaults_corrupted"
        case .fileSystemError: return "system.filesystem_error"
        case .networkNotAvailable: return "system.network_unavailable"
        case .unsupportedDevice: return "system.unsupported_device"
        case .osVersionNotSupported: return "system.os_version_unsupported"
        }
    }
    
    public var title: String {
        switch self {
        case .diskSpaceLow: return "Storage Full"
        case .memoryPressure: return "Low Memory"
        case .backgroundTaskTimeout: return "Background Task Failed"
        case .userDefaultsCorrupted: return "Settings Corrupted"
        case .fileSystemError: return "File System Error"
        case .networkNotAvailable: return "No Network"
        case .unsupportedDevice: return "Unsupported Device"
        case .osVersionNotSupported: return "OS Update Required"
        }
    }
    
    public var message: String {
        switch self {
        case .diskSpaceLow:
            return "Device storage is full. Please free up space to continue."
        case .memoryPressure:
            return "Device is low on memory. Close other apps and try again."
        case .backgroundTaskTimeout:
            return "Background data refresh timed out. Data may not be up to date."
        case .userDefaultsCorrupted(let key):
            return "App settings (\(key)) are corrupted and have been reset."
        case .fileSystemError(let operation, let path):
            return "File system error during \(operation) at \(path)"
        case .networkNotAvailable:
            return "Network connection is not available. Some features may not work."
        case .unsupportedDevice:
            return "This device is not supported. HealthKit features may not be available."
        case .osVersionNotSupported(let required, let current):
            return "OS version \(required) or later is required. Current version: \(current)"
        }
    }
    
    public var userActions: [String] {
        switch self {
        case .diskSpaceLow:
            return ["Delete unused apps", "Remove photos/videos", "Clear app caches"]
        case .memoryPressure:
            return ["Close other apps", "Restart device", "Update to latest iOS"]
        case .backgroundTaskTimeout:
            return ["Ensure app is not restricted", "Check Low Power Mode", "Update app"]
        case .userDefaultsCorrupted:
            return ["Reconfigure app settings", "Restart app", "Contact support if needed"]
        case .fileSystemError:
            return ["Restart app", "Restart device", "Reinstall app if needed"]
        case .networkNotAvailable:
            return ["Check WiFi/cellular", "Try again later", "Restart network settings"]
        case .unsupportedDevice:
            return ["Use supported device", "Update iOS", "Contact support"]
        case .osVersionNotSupported:
            return ["Update iOS", "Check for app updates", "Contact support"]
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .diskSpaceLow, .memoryPressure: return .warning
        case .backgroundTaskTimeout, .userDefaultsCorrupted: return .warning
        case .fileSystemError: return .error
        case .networkNotAvailable: return .info
        case .unsupportedDevice, .osVersionNotSupported: return .critical
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .diskSpaceLow, .memoryPressure: return false
        case .backgroundTaskTimeout: return true
        case .userDefaultsCorrupted: return false
        case .fileSystemError: return true
        case .networkNotAvailable: return true
        case .unsupportedDevice, .osVersionNotSupported: return false
        }
    }
    
    public var underlyingError: Error? {
        return nil
    }
}

// MARK: - Error Extensions

extension RecoveryError {
    /// Default implementation for LocalizedError
    public var errorDescription: String? {
        return message
    }
    
    /// Default implementation for LocalizedError
    public var failureReason: String? {
        return title
    }
    
    /// Default implementation for LocalizedError
    public var recoverySuggestion: String? {
        return userActions.isEmpty ? nil : userActions.joined(separator: " • ")
    }
}

// MARK: - Error Result Type

/// Result type specialized for RecoveryScore errors
public typealias RecoveryResult<T> = Result<T, Error>

// MARK: - Error Utilities

public extension RecoveryError {
    /// Create a user-presentable error summary
    func userSummary() -> (title: String, message: String, actions: [String]) {
        return (title: title, message: message, actions: userActions)
    }
    
    /// Check if this error should be logged
    var shouldLog: Bool {
        return severity.priority >= ErrorSeverity.warning.priority
    }
    
    /// Get error context for logging
    func loggingContext() -> [String: Any] {
        var context: [String: Any] = [
            "code": code,
            "severity": severity.rawValue,
            "retryable": isRetryable
        ]
        
        if let underlying = underlyingError {
            context["underlying"] = underlying.localizedDescription
        }
        
        return context
    }
}