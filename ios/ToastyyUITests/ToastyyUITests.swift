import XCTest

final class ToastyyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPlayableRoundAndCollection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let start = app.buttons["startButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: start)
        waitForExpectations(timeout: 20)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native toaster — ready"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        start.tap()
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 2))
        stop.tap()
        XCTAssertTrue(app.descendants(matching: .any)["roundResult"].waitForExistence(timeout: 2))
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.buttons["collectionButton"].tap()
        XCTAssertTrue(app.navigationBars["Toast collection"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Dry toast"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
    }

    @MainActor
    func testAutomaticBurnAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let start = app.buttons["startButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 20)
        start.tap()
        XCTAssertTrue(app.staticTexts["BURNT"].waitForExistence(timeout: 5))
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let sound = app.switches["soundSetting"]
        XCTAssertTrue(sound.waitForExistence(timeout: 3))
        XCTAssertEqual(sound.value as? String, "1")
        // SwiftUI exposes the full Form row as the switch's accessibility frame.
        // Tap the trailing switch control, rather than the row's inert center.
        sound.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: sound)
        waitForExpectations(timeout: 3)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Turn sound on"].waitForExistence(timeout: 3))
    }
}
