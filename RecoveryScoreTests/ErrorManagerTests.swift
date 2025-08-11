import XCTest
@testable import RecoveryScore

@MainActor
final class ErrorManagerTests: XCTestCase {
    
    var errorManager: ErrorManager!
    
    override func setUp() {
        super.setUp()
        errorManager = ErrorManager(enableAutoDismiss: false, enableRetryMechanism: true)
    }
    
    override func tearDown() {
        errorManager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Error Handling Tests
    
    func testHandleErrorUpdatesState() {
        // Given
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        XCTAssertFalse(errorManager.isShowingError)
        XCTAssertNil(errorManager.currentError)
        
        // When
        errorManager.handleError(error)
        
        // Then
        XCTAssertTrue(errorManager.isShowingError)
        XCTAssertNotNil(errorManager.currentError)
        XCTAssertEqual(errorManager.currentError?.code, error.code)
    }
    
    func testDismissErrorClearsState() {
        // Given
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        errorManager.handleError(error)
        XCTAssertTrue(errorManager.isShowingError)
        
        // When
        errorManager.dismissError()
        
        // Then
        XCTAssertFalse(errorManager.isShowingError)
        XCTAssertNil(errorManager.currentError)
    }
    
    func testErrorHistoryTracking() {
        // Given
        XCTAssertTrue(errorManager.errorHistory.isEmpty)
        
        // When
        let error1 = HealthDataError.notAuthorized(requestedTypes: [])
        let error2 = CalculationError.invalidInput(parameter: "HRV", value: -1)
        
        errorManager.handleError(error1)
        errorManager.dismissError()
        errorManager.handleError(error2)
        
        // Then
        XCTAssertEqual(errorManager.errorHistory.count, 2)
        XCTAssertEqual(errorManager.errorHistory[0].error.code, error1.code)
        XCTAssertEqual(errorManager.errorHistory[1].error.code, error2.code)
    }
    
    func testErrorHistoryLimit() {
        // Given
        let maxHistoryCount = 50
        
        // When - Add more than max count
        for i in 0..<(maxHistoryCount + 10) {
            let error = HealthDataError.dataUnavailable(metric: "test\(i)", timeRange: "now")
            errorManager.handleError(error)
            errorManager.dismissError()
        }
        
        // Then
        XCTAssertEqual(errorManager.errorHistory.count, maxHistoryCount)
        // Should keep the most recent errors
        XCTAssertTrue(errorManager.errorHistory.last!.error.message.contains("test59"))
    }
    
    // MARK: - Retry Mechanism Tests
    
    func testRetryOperation() {
        // Given
        var retryCallCount = 0
        let retryOperation = {
            retryCallCount += 1
        }
        
        let error = HealthDataError.queryTimeout(metric: "HRV")
        XCTAssertTrue(error.isRetryable)
        
        // When
        errorManager.handleError(error, retryOperation: retryOperation)
        errorManager.retryLastOperation()
        
        // Then
        XCTAssertEqual(retryCallCount, 1)
        XCTAssertFalse(errorManager.isShowingError) // Should dismiss after retry
    }
    
    func testRetryNonRetryableError() {
        // Given
        var retryCallCount = 0
        let retryOperation = {
            retryCallCount += 1
        }
        
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        XCTAssertFalse(error.isRetryable)
        
        // When
        errorManager.handleError(error, retryOperation: retryOperation)
        errorManager.retryLastOperation()
        
        // Then
        XCTAssertEqual(retryCallCount, 0) // Should not retry non-retryable errors
        XCTAssertTrue(errorManager.isShowingError) // Should still be showing error
    }
    
    func testRetryWithoutOperation() {
        // Given
        let error = HealthDataError.queryTimeout(metric: "HRV")
        errorManager.handleError(error) // No retry operation provided
        
        // When
        errorManager.retryLastOperation()
        
        // Then - Should not crash, should remain showing error
        XCTAssertTrue(errorManager.isShowingError)
    }
    
    // MARK: - Error Severity Tests
    
    func testCriticalErrorHandling() {
        // Given
        let criticalError = SystemError.osVersionNotSupported(required: "16.0", current: "15.0")
        XCTAssertEqual(criticalError.severity, .critical)
        
        // When
        errorManager.handleError(criticalError)
        
        // Then
        XCTAssertTrue(errorManager.isShowingError)
        XCTAssertTrue(errorManager.hasCriticalErrors)
        
        let presentation = errorManager.getCurrentErrorPresentation()
        XCTAssertEqual(presentation?.severity, .critical)
    }
    
    func testErrorSeverityFiltering() {
        // Given
        let infoError = SystemError.networkNotAvailable  // info severity
        let warningError = HealthDataError.dataUnavailable(metric: "test", timeRange: "today")  // warning severity
        let criticalError = SystemError.osVersionNotSupported(required: "16.0", current: "15.0")  // critical severity
        
        // When
        errorManager.handleError(infoError)
        errorManager.dismissError()
        errorManager.handleError(warningError)
        errorManager.dismissError()
        errorManager.handleError(criticalError)
        
        // Then
        XCTAssertEqual(errorManager.errorCount(for: .info), 1)
        XCTAssertEqual(errorManager.errorCount(for: .warning), 1)
        XCTAssertEqual(errorManager.errorCount(for: .critical), 1)
    }
    
    // MARK: - Error Presentation Tests
    
    func testErrorPresentation() {
        // Given
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        
        // When
        errorManager.handleError(error)
        let presentation = errorManager.getCurrentErrorPresentation()
        
        // Then
        XCTAssertNotNil(presentation)
        XCTAssertEqual(presentation?.title, error.title)
        XCTAssertEqual(presentation?.message, error.message)
        XCTAssertEqual(presentation?.severity, error.severity)
        XCTAssertEqual(presentation?.isRetryable, error.isRetryable)
        XCTAssertTrue(presentation?.isDismissable == true)
    }
    
    func testNoPresentationWhenNoError() {
        // Given - No error
        XCTAssertNil(errorManager.currentError)
        
        // When
        let presentation = errorManager.getCurrentErrorPresentation()
        
        // Then
        XCTAssertNil(presentation)
    }
    
    // MARK: - Recent Errors by Type Tests
    
    func testRecentErrorsByType() {
        // Given
        let healthError1 = HealthDataError.notAuthorized(requestedTypes: [])
        let healthError2 = HealthDataError.dataUnavailable(metric: "HRV", timeRange: "today")
        let calcError = CalculationError.invalidInput(parameter: "HRV", value: -1)
        
        // When
        errorManager.handleError(healthError1)
        errorManager.dismissError()
        errorManager.handleError(calcError)
        errorManager.dismissError()
        errorManager.handleError(healthError2)
        errorManager.dismissError()
        
        // Then
        let healthErrors = errorManager.recentErrors(ofType: HealthDataError.self, limit: 5)
        let calcErrors = errorManager.recentErrors(ofType: CalculationError.self, limit: 5)
        
        XCTAssertEqual(healthErrors.count, 2)
        XCTAssertEqual(calcErrors.count, 1)
    }
    
    // MARK: - Context Tracking Tests
    
    func testErrorContextTracking() {
        // Given
        let error = HealthDataError.queryTimeout(metric: "HRV")
        let context: [String: Any] = ["operation": "fetch", "retry_count": 1]
        
        // When
        errorManager.handleError(error, context: context)
        
        // Then
        XCTAssertEqual(errorManager.errorHistory.count, 1)
        let historyEntry = errorManager.errorHistory.first!
        XCTAssertNotNil(historyEntry.context)
        XCTAssertEqual(historyEntry.context?["operation"] as? String, "fetch")
        XCTAssertEqual(historyEntry.context?["retry_count"] as? Int, 1)
    }
    
    func testClearHistory() {
        // Given
        let error = HealthDataError.notAuthorized(requestedTypes: [])
        errorManager.handleError(error)
        XCTAssertFalse(errorManager.errorHistory.isEmpty)
        
        // When
        errorManager.clearHistory()
        
        // Then
        XCTAssertTrue(errorManager.errorHistory.isEmpty)
    }
    
    // MARK: - Auto-Dismissal Tests
    
    func testAutoDismissalEnabled() {
        // Given
        let autoDismissManager = ErrorManager(enableAutoDismiss: true)
        let error = HealthDataError.dataUnavailable(metric: "HRV", timeRange: "today")
        XCTAssertEqual(error.severity, .warning) // Non-critical error
        
        // When
        autoDismissManager.handleError(error)
        
        // Then
        XCTAssertTrue(autoDismissManager.isShowingError)
        
        // Auto-dismissal is tested via timing, which would require async testing
        // For now, we just verify that auto-dismissal setup doesn't crash
    }
    
    func testCriticalErrorNotAutoDismissed() {
        // Given
        let autoDismissManager = ErrorManager(enableAutoDismiss: true)
        let criticalError = SystemError.osVersionNotSupported(required: "16.0", current: "15.0")
        XCTAssertEqual(criticalError.severity, .critical)
        
        // When
        autoDismissManager.handleError(criticalError)
        
        // Then
        XCTAssertTrue(autoDismissManager.isShowingError)
        // Critical errors should not be auto-dismissed
        // (We can't easily test the timer behavior in unit tests)
    }
    
    // MARK: - Error Type Specific Handling Tests
    
    func testHealthDataErrorSpecificHandling() {
        // Given
        let permissionError = HealthDataError.permissionDenied(metric: "HRV")
        
        // When
        errorManager.handleError(permissionError)
        
        // Then
        XCTAssertTrue(errorManager.isShowingError)
        // Specific handling is internal, but we can verify the error is processed
        XCTAssertNotNil(errorManager.currentError)
    }
    
    func testCalculationErrorSpecificHandling() {
        // Given
        let calcError = CalculationError.missingRequiredData(metrics: ["HRV"])
        
        // When
        errorManager.handleError(calcError)
        
        // Then
        XCTAssertTrue(errorManager.isShowingError)
        XCTAssertNotNil(errorManager.currentError)
    }
    
    // MARK: - Edge Cases
    
    func testHandleMultipleErrorsRapidly() {
        // Given
        let error1 = HealthDataError.notAuthorized(requestedTypes: [])
        let error2 = HealthDataError.queryTimeout(metric: "HRV")
        
        // When - Handle multiple errors without dismissing
        errorManager.handleError(error1)
        errorManager.handleError(error2)
        
        // Then - Should show the latest error
        XCTAssertTrue(errorManager.isShowingError)
        XCTAssertEqual(errorManager.currentError?.code, error2.code)
        XCTAssertEqual(errorManager.errorHistory.count, 2)
    }
    
    func testErrorManagerSingleton() {
        // Given/When
        let manager1 = ErrorManager.shared
        let manager2 = ErrorManager.shared
        
        // Then
        XCTAssertTrue(manager1 === manager2)
    }
}

// MARK: - Mock Error Types for Testing

extension ErrorManagerTests {
    
    struct MockRetryableError: RecoveryError {
        let code = "MOCK_RETRYABLE"
        let title = "Mock Retryable Error"
        let message = "This is a mock retryable error for testing"
        let userActions = ["Retry"]
        let severity = ErrorSeverity.warning
        let isRetryable = true
        let underlyingError: Error? = nil
        
        var errorDescription: String? { message }
        var failureReason: String? { message }
        var recoverySuggestion: String? { "Try the operation again" }
    }
    
    struct MockNonRetryableError: RecoveryError {
        let code = "MOCK_NON_RETRYABLE"
        let title = "Mock Non-Retryable Error"
        let message = "This is a mock non-retryable error for testing"
        let userActions = ["Contact Support"]
        let severity = ErrorSeverity.error
        let isRetryable = false
        let underlyingError: Error? = nil
        
        var errorDescription: String? { message }
        var failureReason: String? { message }
        var recoverySuggestion: String? { "Contact support for assistance" }
    }
}