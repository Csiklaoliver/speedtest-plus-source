import XCTest

final class SpeedtestPlusSimulatorUITests: XCTestCase {
    private func freshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SPHARNESS_RESET_DEFAULTS"] = "1"
        app.launch()
        return app
    }

    func testControlsOpenAndMeasuredValidationCompletes() {
        let app = freshApp()
        XCTAssertTrue(app.buttons["harness.controls"].waitForExistence(timeout: 5))

        app.buttons["harness.run"].tap()
        XCTAssertTrue(app.staticTexts["Local presentation validation completed"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["harness.download"].label.contains("187.4 Mbps"))
        XCTAssertTrue(app.staticTexts["harness.upload"].label.contains("42.8 Mbps"))

        app.buttons["harness.controls"].tap()
        XCTAssertTrue(app.navigationBars["Speedtest+ Controls"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Download minimum"].exists)
        XCTAssertTrue(app.textFields["Download maximum"].exists)
        XCTAssertEqual(app.switches.count, 4)
    }

    func testOfflineModeCompletesWithoutNetworkResult() {
        let app = freshApp()
        app.buttons["harness.controls"].tap()
        XCTAssertTrue(app.navigationBars["Speedtest+ Controls"].waitForExistence(timeout: 5))

        app.switches.element(boundBy: 0).tap()
        app.navigationBars["Speedtest+ Controls"].buttons["Apply"].tap()
        XCTAssertTrue(app.buttons["harness.run"].waitForExistence(timeout: 5))
        app.buttons["harness.run"].tap()

        XCTAssertTrue(app.staticTexts["Offline demo completed locally"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["harness.result"].label.localizedCaseInsensitiveContains("offline"))
    }
}

