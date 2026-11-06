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
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Phase 9")).firstMatch.exists
        )
        XCTAssertTrue(app.descendants(matching: .any)["shell"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["shell.tools"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["shell.viewport"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["shell.inspector"].exists)

        let metalViewport = app.descendants(matching: .any)["shell.viewport.metal"]
        XCTAssertTrue(
            metalViewport.waitForExistence(timeout: 10),
            "Metal viewport did not expose its accessibility surface. Hierarchy:\n\(app.debugDescription)"
        )
        XCTAssertTrue(app.descendants(matching: .any)["shell.viewport.fps"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch-smoke"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
