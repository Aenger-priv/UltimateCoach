import XCTest

final class UltimateCoachUITestsLaunchTests: XCTestCase {
    @MainActor
    func testLargeTextLoggerCanSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let start = app.buttons["Use Today"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        for _ in 0..<6 where !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.buttons["Open workout"].waitForExistence(timeout: 5))
        if !app.buttons["Open workout"].isHittable { app.swipeUp() }
        app.buttons["Open workout"].tap()
        if !app.buttons["Start workout"].isHittable { app.swipeUp() }
        app.buttons["Start workout"].tap()
        let log = app.buttons["exerciseAction_0"]
        for _ in 0..<4 where !log.isHittable { app.swipeUp() }
        XCTAssertTrue(log.isHittable)
        log.tap()
        XCTAssertTrue(app.buttons["saveSet"].waitForExistence(timeout: 5))
        let entry = app.textFields["weightInput"]
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.isHittable)
        app.swipeUp()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark logger at largest text size"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["saveSet"].tap()
        XCTAssertEqual(app.buttons["saveSet"].label, "Save set 2")
    }
}
