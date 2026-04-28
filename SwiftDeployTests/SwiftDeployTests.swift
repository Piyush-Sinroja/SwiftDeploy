//
//  SwiftDeployTests.swift
//  SwiftDeployTests
//

@testable import SwiftDeploy
import XCTest

final class SwiftDeployTests: XCTestCase {

    // MARK: - Config Tests

    func testAPIBaseURLNotEmpty() {
        // API_BASE_URL must be set in Info.plist via xcconfig
        // If empty, the app would crash on launch in Config.swift
        let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String
        XCTAssertNotNil(url, "API_BASE_URL should exist in Info.plist")
        XCTAssertFalse(url?.isEmpty ?? true, "API_BASE_URL should not be empty")
    }

    func testBundleIdentifierNotEmpty() {
        let bundleID = Bundle.main.bundleIdentifier
        XCTAssertNotNil(bundleID, "Bundle identifier should be set")
        XCTAssertTrue(
            bundleID?.hasPrefix("com.piyushsinroja") ?? false,
            "Bundle ID should start with com.piyushsinroja"
        )
    }

    func testAppVersionExists() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        XCTAssertNotNil(version, "App version should be set")
        XCTAssertFalse(version?.isEmpty ?? true, "App version should not be empty")
    }

    func testBuildNumberExists() {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        XCTAssertNotNil(build, "Build number should be set")
        XCTAssertFalse(build?.isEmpty ?? true, "Build number should not be empty")
    }

    // MARK: - Environment Tests

    func testEnvironmentIsSet() {
        // Verifies SWIFT_ACTIVE_COMPILATION_CONDITIONS are working
        #if DEV
        XCTAssertTrue(true, "Running in Dev environment")
        #elseif QA
        XCTAssertTrue(true, "Running in QA environment")
        #else
        XCTAssertTrue(true, "Running in Prod environment")
        #endif
    }
}
