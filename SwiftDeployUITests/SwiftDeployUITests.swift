//
//  SwiftDeployUITests.swift
//  SwiftDeployUITests
//

import XCTest

final class SwiftDeployUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests

    @MainActor
    func testAppLaunchesSuccessfully() {
        // Verifies app launches without crashing
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")
    }

    @MainActor
    func testHomeScreenExists() {
        // Verifies the initial screen is displayed
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }
}
