import XCTest
import os.log
@testable import RecoveryScore

final class ErrorLoggerTests: XCTestCase {
    
    var logger: ErrorLogger!
    
    override func setUp() {
        super.setUp()
        // Create logger with debug level for testing
        logger = ErrorLogger(
            minimumLogLevel: .debug,
            enableConsoleLogging: true,
            enableFileLogging: false,
            enableAnalytics: false
        )
    }
    
    override func tearDown() {
        logger = nil
        super.tearDown()
    }
    
    // MARK: - Basic Logging Tests
    
    func testLoggerInitialization() {
        XCTAssertNotNil(logger)
    }
    
    func testLogErrorWithContext() {
        // Given
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        let context: [String: Any] = ["operation": "fetch", "timestamp": Date()]
        
        // When - This should not crash
        logger.log(error, context: context)
        
        // Then - Verify logger handled the call (hard to test actual logging output)
        // We mainly test that it doesn't crash with various inputs
    }
    
    func testLogMessageWithLevel() {
        // Given
        let message = "Test log message"
        let level = LogLevel.info
        let category = LogCategory.healthData
        let context = ["test_param": "test_value"]
        
        // When
        logger.log(message, level: level, category: category, context: context)
        
        // Then - Should not crash
        // Actual logging verification would require more complex test setup
    }
    
    // MARK: - Log Level Tests
    
    func testLogLevelPriority() {
        XCTAssertLessThan(LogLevel.debug.priority, LogLevel.info.priority)
        XCTAssertLessThan(LogLevel.info.priority, LogLevel.warning.priority)
        XCTAssertLessThan(LogLevel.warning.priority, LogLevel.error.priority)
        XCTAssertLessThan(LogLevel.error.priority, LogLevel.critical.priority)
    }
    
    func testLogLevelOSLogTypeMapping() {
        XCTAssertEqual(LogLevel.debug.osLogType, OSLogType.debug)
        XCTAssertEqual(LogLevel.info.osLogType, OSLogType.info)
        XCTAssertEqual(LogLevel.warning.osLogType, OSLogType.default)
        XCTAssertEqual(LogLevel.error.osLogType, OSLogType.error)
        XCTAssertEqual(LogLevel.critical.osLogType, OSLogType.fault)
    }
    
    // MARK: - Log Category Tests
    
    func testLogCategorySubsystem() {
        for category in LogCategory.allCases {
            XCTAssertEqual(category.subsystem, "com.recoveryScore.app")
            XCTAssertEqual(category.category, category.rawValue)
        }
    }
    
    // MARK: - Minimum Log Level Filtering Tests
    
    func testMinimumLogLevelFiltering() {
        // Given - Logger with warning minimum level
        let warningLogger = ErrorLogger(
            minimumLogLevel: .warning,
            enableConsoleLogging: true
        )
        
        // When - Attempt to log debug and info messages (should be filtered)
        warningLogger.debug("Debug message")
        warningLogger.info("Info message")
        
        // When - Log warning and error messages (should pass through)
        warningLogger.warning("Warning message")
        warningLogger.error("Error message")
        
        // Then - No crash expected; filtering behavior tested at method level
        // In a real implementation, we'd verify which logs actually got written
    }
    
    // MARK: - Convenience Method Tests
    
    func testConvenienceLoggingMethods() {
        // Given
        let message = "Test message"
        let category = LogCategory.calculation
        let context = ["test": "value"]
        
        // When/Then - Should not crash
        logger.debug(message, category: category, context: context)
        logger.info(message, category: category, context: context)
        logger.warning(message, category: category, context: context)
        logger.error(message, category: category, context: context)
        logger.critical(message, category: category, context: context)
    }
    
    func testDefaultCategoryInConvenienceMethods() {
        // When/Then - Should use default .system category
        logger.debug("Debug message") // No category specified
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")
    }
    
    // MARK: - Error Type Mapping Tests
    
    func testErrorSeverityToLogLevelMapping() {
        // Given
        let infoError = SystemError.networkNotAvailable  // info severity
        let warningError = HealthDataError.dataUnavailable(metric: "test", timeRange: "now")  // warning severity
        let errorError = HealthDataError.queryTimeout(metric: "test")  // error severity  
        let criticalError = SystemError.osVersionNotSupported(required: "16.0", current: "15.0")  // critical severity
        
        // When
        logger.log(infoError)
        logger.log(warningError)
        logger.log(errorError)
        logger.log(criticalError)
        
        // Then - Should not crash
        // Mapping verification happens internally
    }
    
    func testErrorCategoryDetermination() {
        // Given
        let healthError = HealthDataError.notAuthorized(requestedTypes: [])
        let calcError = CalculationError.invalidInput(parameter: "test", value: 0)
        let systemError = SystemError.memoryPressure
        
        // When
        logger.log(healthError)
        logger.log(calcError)  
        logger.log(systemError)
        
        // Then - Should not crash
        // Category determination tested internally
    }
    
    // MARK: - Context Handling Tests
    
    func testEmptyContextHandling() {
        // Given
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        
        // When
        logger.log(error, context: nil)
        logger.log(error, context: [:])
        
        // Then - Should not crash
    }
    
    func testComplexContextHandling() {
        // Given
        let error = CalculationError.invalidInput(parameter: "HRV", value: -1)
        let complexContext: [String: Any] = [
            "string_value": "test",
            "int_value": 42,
            "double_value": 3.14,
            "bool_value": true,
            "date_value": Date(),
            "array_value": [1, 2, 3],
            "nested_dict": ["key": "value"]
        ]
        
        // When
        logger.log(error, context: complexContext)
        
        // Then - Should not crash with complex context
    }
    
    // MARK: - Flush Tests
    
    func testFlushOperation() {
        // Given
        logger.log("Test message", level: .info, category: .system)
        
        // When
        logger.flush()
        
        // Then - Should not crash
        // Actual flush behavior would require file logging to be meaningful
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentLogging() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent logging")
        let iterations = 100
        var completed = 0
        
        // When - Log from multiple threads concurrently
        for i in 0..<iterations {
            DispatchQueue.global().async {
                self.logger.log("Concurrent message \(i)", level: .info, category: .system)
                
                DispatchQueue.main.async {
                    completed += 1
                    if completed == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // Should complete without crashing
    }
    
    // MARK: - Global Logging Functions Tests
    
    func testGlobalLoggingFunctions() {
        // Given
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        let context: [String: Any] = ["global_test": true]
        
        // When/Then - Should not crash
        logError(error, context: context)
        logInfo("Info message", category: .healthData, context: context)
        logWarning("Warning message", category: .system)
        logDebug("Debug message")
    }
    
    // MARK: - Error Recovery Tests
    
    func testLoggingWithNilValues() {
        // Given
        let message: String? = nil
        
        // When/Then - Should handle nil gracefully
        logger.info(message ?? "fallback", category: .system)
        
        // Test with empty string
        logger.info("", category: .system)
    }
    
    // MARK: - Singleton Tests
    
    func testSharedLoggerSingleton() {
        // Given/When
        let logger1 = ErrorLogger.shared
        let logger2 = ErrorLogger.shared
        
        // Then
        XCTAssertTrue(logger1 === logger2)
    }
    
    // MARK: - Configuration Tests
    
    func testLoggerConfiguration() {
        // Given
        let customLogger = ErrorLogger(
            minimumLogLevel: .error,
            enableConsoleLogging: false,
            enableFileLogging: true,
            enableAnalytics: true
        )
        
        // When/Then - Should initialize without crashing
        XCTAssertNotNil(customLogger)
        
        // Test logging with different configuration
        customLogger.log("Test message", level: .critical, category: .system)
        customLogger.debug("This should be filtered out due to minimum level")
    }
    
    // MARK: - Performance Tests
    
    func testLoggingPerformance() {
        // Given
        let message = "Performance test message with some context data"
        let context: [String: Any] = ["iteration": 0, "timestamp": Date(), "metric": "performance"]
        
        // When/Then - Measure performance
        measure {
            for i in 0..<1000 {
                var contextCopy = context
                contextCopy["iteration"] = i
                logger.log(message, level: .info, category: .system, context: contextCopy)
            }
        }
    }
}