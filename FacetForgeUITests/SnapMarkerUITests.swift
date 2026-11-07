import XCTest

/// Phase 16's marker evidence. The simulator has no pointer trackpad, so a tap
/// publishes the same hover sample the pointer path uses; the marker must then
/// exist, and it must still exist after a pinch because the overlay re-resolves
/// against the new camera instead of keeping stale screen points.
final class SnapMarkerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testHoverSampleDrawsMarkersAndTheySurviveZoom() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()

        let viewport = element("shell.viewport", app)
        XCTAssertTrue(viewport.waitForExistence(timeout: 30), "shell viewport did not appear")
        let metal = element("shell.viewport.metal", app)
        XCTAssertTrue(metal.waitForExistence(timeout: 20), "Metal viewport did not appear")

        // A point on the lower-left ground plane: the grid candidate is always
        // within half a one-millimetre cell, so no exact feature is required.
        metal.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.78)).tap()

        let markers = app.descendants(matching: .any).matching(identifier: "snap.marker")
        XCTAssertTrue(
            markers.firstMatch.waitForExistence(timeout: 10),
            "no snap marker after the hover sample. Hierarchy:\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            markers.firstMatch.label.hasPrefix("Snap "),
            "marker has no snap label: '\(markers.firstMatch.label)'"
        )
        let count = markers.count
        XCTAssertGreaterThan(count, 0)

        let hoverShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        hoverShot.name = "phase16-snap-markers"
        hoverShot.lifetime = .keepAlways
        add(hoverShot)

        metal.pinch(withScale: 1.3, velocity: 1)

        XCTAssertTrue(
            markers.firstMatch.waitForExistence(timeout: 10),
            "markers vanished after the zoom"
        )
        XCTAssertGreaterThan(markers.count, 0)

        let zoomedShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        zoomedShot.name = "phase16-snap-markers-zoomed"
        zoomedShot.lifetime = .keepAlways
        add(zoomedShot)
    }

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
