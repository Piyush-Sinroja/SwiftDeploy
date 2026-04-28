//
//  SwiftDeployUITests.swift
//  SwiftDeployUITests
//

import XCTest

final class SwiftDeployUITests: XCTestCase {

    var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app?.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests

    @MainActor
    func testAppLaunchesSuccessfully() {
        XCTAssertTrue(app?.state == .runningForeground, "App should be running in foreground")
    }

    @MainActor
    func testHomeScreenExists() {
        XCTAssertTrue(app?.windows.firstMatch.exists ?? false, "App should have at least one window")
    }
}
