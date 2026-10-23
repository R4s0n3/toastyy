import XCTest

final class ToastyyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    /// The lever is a hit area over the 3D handle; it becomes hittable once the loading screen fades.
    private func waitForLever(_ app: XCUIApplication, timeout: TimeInterval = 20) -> XCUIElement {
        let lever = app.descendants(matching: .any)["leverControl"]
        XCTAssertTrue(lever.waitForExistence(timeout: timeout))
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: lever)
        waitForExpectations(timeout: timeout)
        return lever
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPlayableRoundAndCollection() throws {
        let app = launch()
        let lever = waitForLever(app)
        attach(app, "Native toaster — ready")
        lever.tap()
        let stop = app.buttons["stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 2))
        attach(app, "Native toaster — toasting")
        stop.tap()
        XCTAssertTrue(app.descendants(matching: .any)["roundResult"].waitForExistence(timeout: 2))
        attach(app, "Native toaster — result")
        _ = waitForLever(app, timeout: 6)
        app.buttons["collectionButton"].tap()
        XCTAssertTrue(app.staticTexts["Toast, evolved."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Dry toast"].exists)
        attach(app, "Native toaster — collection")
        app.buttons["collectionClose"].tap()
        _ = waitForLever(app, timeout: 3)
    }

    @MainActor
    func testAutomaticBurnSettingsAndRecords() throws {
        let app = launch()
        waitForLever(app).tap()
        XCTAssertTrue(app.staticTexts["BURNT"].waitForExistence(timeout: 5))
        attach(app, "Native toaster — burnt")
        _ = waitForLever(app, timeout: 6)

        app.buttons["helpButton"].tap()
        let sound = app.buttons["soundSetting"]
        XCTAssertTrue(sound.waitForExistence(timeout: 3))
        XCTAssertEqual(sound.value as? String, "ON")
        attach(app, "Native toaster — settings")
        sound.tap()
        expectation(for: NSPredicate(format: "value == 'OFF'"), evaluatedWith: sound)
        waitForExpectations(timeout: 3)
        app.buttons["settingsDone"].tap()
        _ = waitForLever(app, timeout: 3)
        XCTAssertEqual(app.buttons["soundControl"].label, "Turn sound on")

        app.buttons["recordsControl"].tap()
        XCTAssertTrue(app.staticTexts["Cabinet records"].waitForExistence(timeout: 3))
        attach(app, "Native toaster — records")
        app.buttons["recordsDone"].tap()
        _ = waitForLever(app, timeout: 3)

        let knob = app.descendants(matching: .any)["knobControl"]
        XCTAssertEqual(knob.value as? String, "Golden")
        knob.tap()
        expectation(for: NSPredicate(format: "value == 'Crispy'"), evaluatedWith: knob)
        waitForExpectations(timeout: 3)
        attach(app, "Native toaster — crispy")
    }
}
