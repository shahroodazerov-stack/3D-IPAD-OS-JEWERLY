import XCTest

final class LaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsIdentityAndStaysInTheForeground() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        let title = app.staticTexts["FacetForge"]
        if !title.waitForExistence(timeout: 10) {
            XCTFail("FacetForge title did not appear. Hierarchy:\n\(app.debugDescription)")
        }
        XCTAssertTrue(app.staticTexts["iPad CAD for jewellers"].exists)
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Phase 4")).firstMatch.exists
        )
        XCTAssertTrue(app.otherElements["shell"].exists)
        XCTAssertTrue(app.otherElements["shell.tools"].exists)
        XCTAssertTrue(app.otherElements["shell.viewport"].exists)
        XCTAssertTrue(app.otherElements["shell.inspector"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch-smoke"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
