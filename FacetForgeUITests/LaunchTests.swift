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
        XCTAssertTrue(app.staticTexts["launch.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["launch.title"].label, "FacetForge")
        XCTAssertEqual(app.staticTexts["launch.tagline"].label, "iPad CAD for jewellers")
        XCTAssertTrue(app.staticTexts["launch.phase"].label.contains("Phase 2"))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch-smoke"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
