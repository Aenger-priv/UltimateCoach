import XCTest

final class UltimateCoachUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testAdaptiveRestOfferCanBeUsedOnceAndOrdinaryControlRemainsAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--rest-offer", "-adaptive_rest", "YES"]
        app.launch()
        let resume = app.buttons["Resume workout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        resume.tap()
        XCTAssertTrue(app.buttons["Suggested: add 30 seconds"].exists)
        app.buttons["Log next set"].tap()
        let offer = app.buttons["Suggested: add 30 seconds"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5))
        offer.tap()
        XCTAssertTrue(app.buttons["Add 30 seconds"].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Add 30 seconds"].isHittable)
    }

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
        let logger = app.buttons["Log next set"]
        XCTAssertTrue(logger.waitForExistence(timeout: 5))
        if !logger.isHittable { app.swipeUp() }
        logger.tap()
        XCTAssertTrue(app.textFields["weightInput"].waitForExistence(timeout: 5))
        capture("Dark set logger", app: app)
        app.buttons["saveSet"].tap()
        XCTAssertTrue(app.buttons["Add 30 seconds"].waitForExistence(timeout: 5))
        app.buttons["Add 30 seconds"].tap()
        app.buttons["Undo last set"].tap()
        XCTAssertEqual(app.buttons["saveSet"].label, "Save set 1")
        for _ in 0..<4 { app.buttons["saveSet"].tap() }
        XCTAssertTrue(app.staticTexts["All 4 sets saved"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveSet"].exists)
        app.buttons["Next exercise"].tap()
        XCTAssertTrue(app.staticTexts["Barbell Row"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["saveSet"].label, "Save set 1")
        app.buttons["Done"].firstMatch.tap()
        let endRest = app.buttons["End rest"]
        XCTAssertTrue(endRest.waitForExistence(timeout: 5))
        endRest.tap()
        XCTAssertTrue(endRest.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["Resume workout"].waitForExistence(timeout: 5))
        app.buttons["Resume workout"].tap()
        XCTAssertTrue(app.staticTexts["4 of 18 sets saved"].waitForExistence(timeout: 5))
        app.buttons["Finish workout"].tap()
        app.buttons["Finish and save"].tap()
        XCTAssertTrue(app.staticTexts["Finished"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        let benchTrend = app.buttons["exerciseTrend_Bench Press_barbell"]
        for _ in 0..<4 where !benchTrend.isHittable { app.swipeUp() }
        XCTAssertTrue(benchTrend.waitForExistence(timeout: 5))
        benchTrend.tap()
        let metric = app.buttons["exerciseTrendMetric"]
        XCTAssertTrue(metric.waitForExistence(timeout: 5))
        XCTAssertEqual(metric.value as? String, "Heaviest set")
        XCTAssertTrue(app.staticTexts["latestTrendValue"].exists)
        XCTAssertTrue(app.staticTexts["Log another qualifying workout to see a trend."].exists)
        metric.tap()
        app.buttons["Estimated 1-rep max"].tap()
        XCTAssertEqual(metric.value as? String, "Estimated 1-rep max")
        app.navigationBars.buttons["Progress"].tap()
        let history = app.buttons["historyWorkout_1_1"]
        for _ in 0..<4 where !history.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Workout history"].waitForExistence(timeout: 5))
        history.tap()
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
    func testCycleDashboardShowsAttendancePerformanceAndRowingComparison() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--cycle-progress"]
        app.launch()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "2 of 52 workouts finished"))
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "1 of 4 finished"))
            .firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "8 → 9 reps at 50 kg"))
            .firstMatch.exists)
        capture("Cycle dashboard", app: app)
        let details = app.buttons["cycleDetails"]
        for _ in 0..<5 where !details.isHittable { app.swipeUp() }
        details.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "4 of 68"))
            .firstMatch.exists)
        XCTAssertTrue(app.staticTexts["15-minute row"].exists)
        for _ in 0..<5 where !app.staticTexts["Choose the next emphasis"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Choose the next emphasis"].isHittable)
    }

    @MainActor
    func testCycleDetailsAreReachableAtLargestText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--cycle-progress", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Progress"].tap()
        capture("Cycle dashboard at largest text", app: app)
        let details = app.buttons["cycleDetails"]
        for _ in 0..<8 where !details.isHittable { app.swipeUp() }
        XCTAssertTrue(details.isHittable)
        details.tap()
        XCTAssertTrue(app.navigationBars["Cycle details"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSetUpTimedRowWithoutConnectingAMonitor() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let today = app.buttons["Use Today"]
        for _ in 0..<4 where !today.isHittable { app.swipeUp() }
        today.tap()
        app.buttons["Open workout"].tap()
        let setup = app.buttons["Set up RowErg"]
        for _ in 0..<12 where !setup.isHittable { app.swipeUp() }
        setup.tap()
        XCTAssertTrue(app.buttons["Find a PM5"].waitForExistence(timeout: 5))
        app.buttons["Set up manually"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "single time"))
            .firstMatch.exists)
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
        let options = app.buttons["Options for Bench Press"]
        for _ in 0..<3 where !options.isHittable { app.swipeUp() }
        options.tap()
        app.buttons["Swap exercise"].tap()
        let pushUp = app.buttons.containing(.staticText, identifier: "Push-Up").firstMatch
        XCTAssertTrue(pushUp.waitForExistence(timeout: 5))
        pushUp.tap()
        app.buttons["Swap"].tap()
        XCTAssertTrue(app.staticTexts["Push-Up"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Program"].tap()
        XCTAssertTrue(app.staticTexts["Strength"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Day 1 · Mixed Upper"].exists)
        XCTAssertTrue(app.staticTexts["Day 2 · Lower Body"].exists)
        let picker = app.buttons["trainingWeekPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let deload = app.buttons["Week 13 · Deload"]
        XCTAssertTrue(deload.waitForExistence(timeout: 5))
        deload.tap()
        XCTAssertTrue(app.staticTexts["Day 1 · Mixed Upper"].waitForExistence(timeout: 5))
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
    func testEndProgramEarlyKeepsWorkAndStartsAnotherTrack() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["track_strength"].waitForExistence(timeout: 10))
        app.buttons["track_strength"].tap()
        let create = app.buttons["createCycle"]
        for _ in 0..<4 where !create.isHittable { app.swipeUp() }
        create.tap()
        XCTAssertTrue(app.buttons["Open workout"].waitForExistence(timeout: 5))
        app.buttons["Open workout"].tap()
        app.buttons["Start workout"].tap()
        let lift = app.buttons["exerciseAction_0"]
        for _ in 0..<3 where !lift.isHittable { app.swipeUp() }
        lift.tap()
        app.buttons["saveSet"].tap()
        app.buttons["Done"].firstMatch.tap()

        app.tabBars.buttons["Program"].tap()
        let end = app.buttons["End program early"]
        for _ in 0..<4 where !end.isHittable { app.swipeUp() }
        XCTAssertTrue(end.isHittable)
        end.tap()
        app.alerts.buttons["Keep program"].tap()
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        app.alerts.buttons["End and choose a track"].tap()

        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertEqual(create.label, "Start Hypertrophy cycle")
        app.buttons["Cancel"].tap()
        let restart = app.buttons["Choose next track"]
        XCTAssertTrue(restart.waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.buttons["historyWorkout_1_1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 set saved"].exists)
        app.tabBars.buttons["Program"].tap()
        restart.tap()
        for _ in 0..<4 where !create.isHittable { app.swipeUp() }
        create.tap()
        XCTAssertTrue(app.staticTexts["Hypertrophy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Day 1 · Mixed Upper"].exists)
    }

    @MainActor
    func testMissedWorkoutCanBeMovedToTheSuggestedOpenDateFromToday() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--missed-workout"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Missed workout"].waitForExistence(timeout: 10))
        let reschedule = app.buttons["Reschedule"]
        for _ in 0..<4 where !reschedule.isHittable { app.swipeUp() }
        reschedule.tap()
        let save = app.navigationBars["Reschedule"].buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.staticTexts["Missed workout"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open workout"].exists)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
