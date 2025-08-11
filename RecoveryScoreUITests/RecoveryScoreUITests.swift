//
//  RecoveryScoreUITests.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 25/07/2025.
//

import XCTest

final class Athletica_OSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            let options = XCTMeasureOptions()
            options.iterationCount = 1 // avoid multiple iterations where metrics may be missing
            measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
                let app = XCUIApplication()
                app.launchArguments = ["-uiTesting"]
                app.launch()
            }
        } else {
            throw XCTSkip("Launch performance metric requires iOS 13+")
        }
    }
}
