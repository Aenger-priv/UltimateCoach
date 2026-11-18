import XCTest

final class UltimateCoachUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testOnboardingLoggingResumeAndHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Use Today"].waitForExistence(timeout: 10))
        for _ in 0..<4 where !app.buttons["Use Today"].isHittable { app.swipeUp() }
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
        XCTAssertTrue(app.staticTexts["4 of 18 sets saved"].waitForExistence(timeout: 5))
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
    func testStrengthTrackAndDeloadAreVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let strength = app.buttons["track_strength"]
        XCTAssertTrue(strength.waitForExistence(timeout: 10))
        if !strength.isHittable { app.swipeUp() }
        strength.tap()
        capture("Training track selection", app: app)
        let create = app.buttons["createCycle"]
        for _ in 0..<4 where !create.isHittable { app.swipeUp() }
        create.tap()
        XCTAssertTrue(app.buttons["Open workout"].waitForExistence(timeout: 5))
        app.buttons["Open workout"].tap()
        XCTAssertTrue(app.staticTexts["3 sets · 3–5 reps"].exists)
        app.tabBars.buttons["Program"].tap()
        let picker = app.buttons["trainingWeekPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let deload = app.buttons["Week 13 · Deload"]
        XCTAssertTrue(deload.waitForExistence(timeout: 5))
        deload.tap()
        XCTAssertTrue(app.staticTexts["Day 1"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExpiredCycleSuggestsOppositeTrackAndRequiresConfirmation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--expired-cycle"]
        app.launch()
        let rollover = app.buttons["Choose next track"]
        XCTAssertTrue(rollover.waitForExistence(timeout: 10))
        rollover.tap()
        let confirm = app.buttons["createCycle"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, "Start Strength cycle")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(rollover.waitForExistence(timeout: 5))
        rollover.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        for _ in 0..<4 where !confirm.isHittable { app.swipeUp() }
        confirm.tap()
        XCTAssertTrue(app.buttons["Open workout"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Program"].tap()
        XCTAssertTrue(app.staticTexts["Strength"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
