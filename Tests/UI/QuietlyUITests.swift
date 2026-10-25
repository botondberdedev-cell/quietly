import XCTest

@MainActor
final class QuietlyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-quietly-ui-testing", "-quietly-reset"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
    }

    private func reveal(_ element: XCUIElement, attempts: Int = 12) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews.firstMatch
            if scroll.exists { scroll.swipeUp(velocity: .slow) }
            else { app.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(element.isHittable, "Expected a reachable control: \(element)")
    }

    private func onboard() {
        let start = app.buttons["Open Instagram"]
        reveal(start)
        start.tap()
        XCTAssertTrue(app.buttons["session.end"].waitForExistence(timeout: 5))
    }

    private func endVisit() {
        app.buttons["session.end"].tap()
        XCTAssertTrue(app.buttons["Open Instagram"].waitForExistence(timeout: 5))
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOpensDirectlyIntoInstagramAndRestoresVisit() {
        onboard()
        XCTAssertTrue(app.buttons["tab.home"].exists)
        XCTAssertTrue(app.buttons["tab.messages"].exists)
        XCTAssertTrue(app.webViews.firstMatch.exists)
        screenshot("Instagram home shell")
        app.terminate()
        app.launchArguments = ["-quietly-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["session.end"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Open Instagram"].exists)
    }

    func testOnboardingFriendValidationPersistenceAndRemoval() {
        screenshot("Onboarding")
        onboard()
        app.buttons["settings.open"].tap()
        let input = app.textFields["Friend’s Instagram username"]
        reveal(input)
        input.tap()
        input.typeText("https://example.com")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Enter a username, such as @alex, without a website address."].exists)
        input.tap()
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "https://example.com".count))
        input.typeText("@Alex")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["@alex"].waitForExistence(timeout: 3))
        screenshot("Friend added in Settings")
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["session.end"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-quietly-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 5))
        app.buttons["settings.open"].tap()
        screenshot("Settings after relaunch")
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["@alex"])
        app.staticTexts["@alex"].swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertFalse(app.staticTexts["@alex"].exists)
    }

    func testVisitExpiryAfterBackgroundAndRelaunch() {
        // Choose the real one-minute duration before starting the first visit.
        reveal(app.buttons["settings.open"])
        app.buttons["settings.open"].tap()
        let length = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Visit length")).firstMatch
        reveal(length)
        length.tap()
        app.buttons["1 minute"].tap()
        app.buttons["settings.done"].tap()
        onboard()
        XCUIDevice.shared.press(.home)
        let wait = expectation(description: "Visit deadline passes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 62) { wait.fulfill() }
        waitForExpectations(timeout: 65)
        app.terminate()
        app.launchArguments = ["-quietly-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Back to my day"].waitForExistence(timeout: 10))
        screenshot("Visit complete")
        app.buttons["Back to my day"].tap()
        XCTAssertTrue(app.buttons["Open Instagram"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["1 visit brought to a close."])
    }

    func testVisitCanEndImmediately() {
        onboard()
        endVisit()
        reveal(app.staticTexts["1 visit brought to a close."])
    }

    func testNotificationOptInAndSystemTestBanner() {
        reveal(app.buttons["settings.open"])
        app.buttons["settings.open"].tap()
        let toggle = app.switches["notifications.enabled"]
        reveal(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["notifications.test"].exists)
        // SwiftUI exposes the full labelled row as a switch; target its trailing control.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        else if app.alerts.buttons["Allow"].exists { app.alerts.buttons["Allow"].tap() }
        let test = app.buttons["notifications.test"]
        reveal(test)
        XCTAssertTrue(test.waitForExistence(timeout: 5))
        test.tap()
        XCTAssertTrue(app.staticTexts["Test notification sent. iPhone notification settings control its appearance and sound."].waitForExistence(timeout: 5))
        XCTAssertTrue(springboard.staticTexts["Quietly notification test"].waitForExistence(timeout: 5))
        screenshot("Notification settings and test")
    }

    func testWebsiteDataDeletionHasConfirmationAndCompletion() {
        onboard()
        app.buttons["settings.open"].tap()
        let clear = app.buttons["Clear Instagram login & website data"]
        reveal(clear)
        clear.tap()
        XCTAssertTrue(app.buttons["Clear website data"].waitForExistence(timeout: 3))
        app.buttons["Clear website data"].tap()
        let cleared = app.staticTexts["Website data cleared on this device."]
        reveal(cleared)
        XCTAssertTrue(cleared.waitForExistence(timeout: 15))
    }

    func testLargeTextAndLandscapeKeepPrimaryActionsReachable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        onboard()
        XCTAssertTrue(app.buttons["settings.open"].isHittable)
        endVisit()
        screenshot("Accessibility text pause screen")
        XCUIDevice.shared.orientation = .landscapeLeft
        reveal(app.buttons["Open Instagram"])
        screenshot("Landscape pause screen")
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        screenshot("Landscape settings")
    }

    func testPauseScreenAccessibility() throws {
        onboard()
        endVisit()
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .textClipped])
    }
}
