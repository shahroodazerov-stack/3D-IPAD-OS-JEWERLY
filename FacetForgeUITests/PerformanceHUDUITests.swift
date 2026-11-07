import XCTest

/// Phase 21's acceptance. The overlay is reachable from the viewport HUD, shows
/// the live frame's counters rather than a placeholder, and goes away when the
/// chip is tapped again.
final class PerformanceHUDUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testHUDTogglesThePerformanceOverlayAndItsCountersAreLive() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()

        let metal = element("shell.viewport.metal", app)
        XCTAssertTrue(metal.waitForExistence(timeout: 30), "Metal viewport did not appear")

        let toggle = element("hud.performance.toggle", app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "the HUD has no performance chip")
        XCTAssertEqual(toggle.value as? String, "Off", "the overlay should start hidden")

        let overlay = element("hud.performance.overlay", app)
        XCTAssertFalse(overlay.exists, "the overlay was visible before the chip was tapped")

        toggle.tap()
        XCTAssertTrue(overlay.waitForExistence(timeout: 10), "tapping the chip did not show the overlay")
        XCTAssertEqual(toggle.value as? String, "On")

        // A running bench scene has geometry and reference lines, so the
        // encoded frame cannot legitimately report zero draw calls. Waiting for
        // a non-zero count proves the overlay is fed by the renderer rather
        // than by the report's defaults.
        let live = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label MATCHES %@", ".*draw calls [1-9][0-9]*,.*"),
            object: overlay
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [live], timeout: 15),
            .completed,
            "the overlay never reported encoded draw calls: '\(overlay.label)'"
        )

        let label = overlay.label
        XCTAssertTrue(label.contains("triangles"), "the overlay does not name triangles: '\(label)'")
        XCTAssertTrue(label.contains("triangles 0,") == false, "the bench scene reported zero triangles: '\(label)'")
        XCTAssertTrue(label.contains("frame"), "the overlay does not name frame time: '\(label)'")
        XCTAssertTrue(label.contains("memory"), "the overlay does not name memory headroom: '\(label)'")
        XCTAssertTrue(label.contains("thermal"), "the overlay does not name thermal state: '\(label)'")
        XCTAssertTrue(
            label.contains("Nominal") || label.contains("Fair")
                || label.contains("Serious") || label.contains("Critical"),
            "thermal state was not a ProcessInfo case: '\(label)'"
        )

        let shownShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shownShot.name = "phase21-performance-hud"
        shownShot.lifetime = .keepAlways
        add(shownShot)

        toggle.tap()
        let hidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: overlay
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [hidden], timeout: 10),
            .completed,
            "tapping the chip again did not hide the overlay"
        )
        XCTAssertEqual(toggle.value as? String, "Off")
    }

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
