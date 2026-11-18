import XCTest

final class UltimateCoachUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testOnboardingLoggingResumeAndHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Use Today"].waitForExistence(timeout: 10))
        app.buttons["Use Today"].tap()
        XCTAssertTrue(app.buttons["Open workout"].waitForExistence(timeout: 5))
        capture("Dark Today", app: app)
        app.buttons["Open workout"].tap()
        let target = app.buttons["Edit target weight, Bench Press"]
        if !target.isHittable { app.swipeUp() }
        target.tap()
        XCTAssertTrue(app.textFields["Target weight in kilograms"].waitForExistence(timeout: 5))
        app.buttons["Save target weight"].tap()
        XCTAssertTrue(app.staticTexts["You set this target."].waitForExistence(timeout: 5))
        if !app.buttons["Start workout"].isHittable { app.swipeDown() }
        app.buttons["Start workout"].tap()
        let logger = app.buttons["exerciseAction_0"]
        XCTAssertTrue(logger.waitForExistence(timeout: 5))
        if !logger.isHittable { app.swipeUp() }
        logger.tap()
        XCTAssertTrue(app.textFields["weightInput"].waitForExistence(timeout: 5))
        capture("Dark set logger", app: app)
        for _ in 0..<4 { app.buttons["saveSet"].tap() }
        XCTAssertTrue(app.staticTexts["All 4 sets saved"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveSet"].exists)
        app.buttons["Done"].firstMatch.tap()
        app.navigationBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["Resume workout"].waitForExistence(timeout: 5))
        app.buttons["Resume workout"].tap()
        XCTAssertTrue(app.staticTexts["4 of 16 sets saved"].waitForExistence(timeout: 5))
        app.buttons["Finish workout"].tap()
        app.buttons["Finish and save"].tap()
        XCTAssertTrue(app.staticTexts["Finished"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Workout history"].waitForExistence(timeout: 5))
        app.buttons["historyWorkout_1_1"].tap()
        let viewSets = app.buttons["exerciseAction_0"]
        for _ in 0..<3 where !viewSets.isHittable { app.swipeUp() }
        viewSets.tap()
        let edit = app.buttons["Edit set 1"]
        for _ in 0..<3 where !edit.isHittable { app.swipeUp() }
        edit.tap()
        XCTAssertTrue(app.textFields["weightInput"].isHittable)
        XCTAssertEqual(app.buttons["saveSet"].label, "Save changes")
        app.buttons["saveSet"].tap()
        XCTAssertTrue(app.buttons["Edit set 1"].isHittable)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
