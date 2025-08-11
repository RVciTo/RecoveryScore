///
/// ErrorLogger.swift
/// RecoveryScore
///
/// Centralized error logging and monitoring system.
/// Provides structured logging with different severity levels and context.
///

import Foundation
import os.log

// MARK: - Error Logger Protocol

public protocol ErrorLogging {
    func log(_ error: RecoveryError, context: [String: Any]?)
    func log(_ message: String, level: LogLevel, category: LogCategory, context: [String: Any]?)
    func flush()
}

// MARK: - Log Level

public enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    public var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    public var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Log Category

public enum LogCategory: String, CaseIterable {
    case healthData = "health_data"
    case calculation = "calculation"
    case userInterface = "user_interface"
    case system = "system"
    case network = "network"
    case persistence = "persistence"
    case authentication = "authentication"
    
    public var subsystem: String {
        return "com.recoveryScore.app"
    }
    
    public var category: String {
        return rawValue
    }
}

// MARK: - Error Logger Implementation

public final class ErrorLogger: ErrorLogging {
    
    // MARK: - Singleton
    
    public static let shared = ErrorLogger()
    
    // MARK: - Properties
    
    private let minimumLogLevel: LogLevel
    private let enableConsoleLogging: Bool
    private let enableFileLogging: Bool
    private let enableAnalytics: Bool
    
    private var loggers: [LogCategory: Logger] = [:]
    private let logQueue = DispatchQueue(label: "com.recoveryScore.errorLogger", qos: .utility)
    
    // MARK: - Initialization
    
    public init(
        minimumLogLevel: LogLevel = .info,
        enableConsoleLogging: Bool = true,
        enableFileLogging: Bool = false,
        enableAnalytics: Bool = false
    ) {
        self.minimumLogLevel = minimumLogLevel
        self.enableConsoleLogging = enableConsoleLogging
        self.enableFileLogging = enableFileLogging
        self.enableAnalytics = enableAnalytics
        
        setupLoggers()
    }
    
    // MARK: - Setup
    
    private func setupLoggers() {
        for category in LogCategory.allCases {
            loggers[category] = Logger(subsystem: category.subsystem, category: category.category)
        }
    }
    
    // MARK: - Public Logging Methods
    
    public func log(_ error: RecoveryError, context: [String: Any]? = nil) {
        let level = mapSeverityToLogLevel(error.severity)
        let category = determineCategory(for: error)
        
        var fullContext = error.loggingContext()
        if let additionalContext = context {
            fullContext.merge(additionalContext) { _, new in new }
        }
        
        log(
            "[\(error.code)] \(error.title): \(error.message)",
            level: level,
            category: category,
            context: fullContext
        )
    }
    
    public func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        context: [String: Any]? = nil
    ) {
        guard level.priority >= minimumLogLevel.priority else { return }
        
        logQueue.async { [weak self] in
            self?.performLogging(message, level: level, category: category, context: context)
        }
    }
    
    public func flush() {
        logQueue.sync {
            // Force flush any buffered logs
            if enableFileLogging {
                // Implement file log flushing if needed
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performLogging(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        context: [String: Any]?
    ) {
        // Console logging (OSLog)
        if enableConsoleLogging {
            logToConsole(message, level: level, category: category, context: context)
        }
        
        // File logging
        if enableFileLogging {
            logToFile(message, level: level, category: category, context: context)
        }
        
        // Analytics/Crash reporting
        if enableAnalytics && level.priority >= LogLevel.error.priority {
            logToAnalytics(message, level: level, category: category, context: context)
        }
    }
    
    private func logToConsole(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        context: [String: Any]?
    ) {
        guard let logger = loggers[category] else { return }
        
        var fullMessage = message
        if let context = context, !context.isEmpty {
            let contextString = formatContext(context)
            fullMessage += " | Context: \(contextString)"
        }
        
        switch level {
        case .debug:
            logger.debug("\(fullMessage, privacy: .public)")
        case .info:
            logger.info("\(fullMessage, privacy: .public)")
        case .warning:
            logger.warning("\(fullMessage, privacy: .public)")
        case .error:
            logger.error("\(fullMessage, privacy: .public)")
        case .critical:
            logger.critical("\(fullMessage, privacy: .public)")
        }
    }
    
    private func logToFile(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        context: [String: Any]?
    ) {
        // Implement file logging if needed
        // This could write to a structured log file for debugging
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue.uppercased())] [\(category.rawValue)] \(message)"
        
        // Write to file (implementation depends on requirements)
        // For now, just print to debug console as fallback
        #if DEBUG
        print("FILE_LOG: \(logEntry)")
        if let context = context {
            print("CONTEXT: \(formatContext(context))")
        }
        #endif
    }
    
    private func logToAnalytics(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        context: [String: Any]?
    ) {
        // Integration point for crash reporting services like Crashlytics
        // For now, just prepare the data structure
        
        var analyticsData: [String: Any] = [
            "level": level.rawValue,
            "category": category.rawValue,
            "message": message,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let context = context {
            analyticsData["context"] = context
        }
        
        // Note: Future integration point for crash reporting services (Firebase, Sentry, etc.)
        #if DEBUG
        print("ANALYTICS_LOG: \(analyticsData)")
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func mapSeverityToLogLevel(_ severity: ErrorSeverity) -> LogLevel {
        switch severity {
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
    
    private func determineCategory(for error: RecoveryError) -> LogCategory {
        switch error {
        case is HealthDataError:
            return .healthData
        case is CalculationError:
            return .calculation
        case is SystemError:
            return .system
        default:
            return .system
        }
    }
    
    private func formatContext(_ context: [String: Any]) -> String {
        return context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }
}

// MARK: - Convenience Extensions

public extension ErrorLogger {
    
    /// Log debug message
    func debug(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
        log(message, level: .debug, category: category, context: context)
    }
    
    /// Log info message
    func info(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
        log(message, level: .info, category: category, context: context)
    }
    
    /// Log warning message
    func warning(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
        log(message, level: .warning, category: category, context: context)
    }
    
    /// Log error message
    func error(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
        log(message, level: .error, category: category, context: context)
    }
    
    /// Log critical message
    func critical(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
        log(message, level: .critical, category: category, context: context)
    }
}

// MARK: - Global Logging Functions

/// Global convenience functions for common logging operations
public func logError(_ error: RecoveryError, context: [String: Any]? = nil) {
    ErrorLogger.shared.log(error, context: context)
}

public func logInfo(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
    ErrorLogger.shared.info(message, category: category, context: context)
}

public func logWarning(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
    ErrorLogger.shared.warning(message, category: category, context: context)
}

public func logDebug(_ message: String, category: LogCategory = .system, context: [String: Any]? = nil) {
    ErrorLogger.shared.debug(message, category: category, context: context)
}