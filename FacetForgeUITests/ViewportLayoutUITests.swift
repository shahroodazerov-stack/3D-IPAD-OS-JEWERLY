import XCTest

/// Phase 13's layout acceptance is a rendered-window assertion, not a plan
/// value: a fresh app must show one maximised Perspective pane, and the four-up
/// chip must produce four non-overlapping panes before returning to the single
/// default.
final class ViewportLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testDefaultIsSinglePerspectiveAndFourUpPresetRestores() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()

        let viewport = element("shell.viewport", app)
        XCTAssertTrue(viewport.waitForExistence(timeout: 30), "shell viewport did not appear. Hierarchy:\n\(app.debugDescription)")

        let perspective = element("shell.viewport.pane.perspective", app)
        XCTAssertTrue(perspective.waitForExistence(timeout: 20), "default Perspective pane is missing")
        XCTAssertFalse(element("shell.viewport.pane.top", app).exists, "four-up is not the default")
        XCTAssertFalse(element("shell.viewport.pane.front", app).exists, "four-up is not the default")
        XCTAssertFalse(element("shell.viewport.pane.right", app).exists, "four-up is not the default")

        assertSinglePaneFillsViewport(perspective, viewport)

        let defaultShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        defaultShot.name = "phase13-default-single-perspective"
        defaultShot.lifetime = .keepAlways
        add(defaultShot)

        let fourUp = app.buttons["shell.viewport.layout.fourUp"]
        XCTAssertTrue(fourUp.waitForExistence(timeout: 10), "four-up layout chip is missing")
        fourUp.tap()

        let top = element("shell.viewport.pane.top", app)
        let front = element("shell.viewport.pane.front", app)
        let right = element("shell.viewport.pane.right", app)
        XCTAssertTrue(top.waitForExistence(timeout: 15), "Top pane did not appear")
        XCTAssertTrue(front.waitForExistence(timeout: 15), "Front pane did not appear")
        XCTAssertTrue(right.waitForExistence(timeout: 15), "Right pane did not appear")
        XCTAssertTrue(perspective.exists, "Perspective pane disappeared in four-up")

        assertFourUpPanesShareTheViewport(perspective, top, front, right, viewport)

        let fourUpShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        fourUpShot.name = "phase13-four-up-preset"
        fourUpShot.lifetime = .keepAlways
        add(fourUpShot)

        app.buttons["shell.viewport.layout.single"].tap()
        XCTAssertTrue(perspective.waitForExistence(timeout: 15), "single pane did not return")
        waitForDisappearance(top, timeout: 15, "Top pane survived the return to single")
        waitForDisappearance(front, timeout: 15, "Front pane survived the return to single")
        waitForDisappearance(right, timeout: 15, "Right pane survived the return to single")
        assertSinglePaneFillsViewport(perspective, viewport)

        let restoredShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        restoredShot.name = "phase13-restored-single-perspective"
        restoredShot.lifetime = .keepAlways
        add(restoredShot)
    }

    @MainActor
    private func assertSinglePaneFillsViewport(_ pane: XCUIElement, _ viewport: XCUIElement) {
        XCTAssertGreaterThan(viewport.frame.width, 200)
        XCTAssertGreaterThan(viewport.frame.height, 200)
        XCTAssertEqual(pane.frame.minX, viewport.frame.minX, accuracy: 3, "single pane is inset at the left")
        XCTAssertEqual(pane.frame.minY, viewport.frame.minY, accuracy: 3, "single pane is inset at the top")
        XCTAssertEqual(pane.frame.width, viewport.frame.width, accuracy: 3, "single pane is not maximised horizontally")
        XCTAssertEqual(pane.frame.height, viewport.frame.height, accuracy: 3, "single pane is not maximised vertically")
    }

    @MainActor
    private func assertFourUpPanesShareTheViewport(
        _ perspective: XCUIElement,
        _ top: XCUIElement,
        _ front: XCUIElement,
        _ right: XCUIElement,
        _ viewport: XCUIElement
    ) {
        let halfWidth = viewport.frame.width / 2
        let halfHeight = viewport.frame.height / 2

        XCTAssertEqual(perspective.frame.width, top.frame.width, accuracy: 3, "top row panes differ in width")
        XCTAssertEqual(front.frame.width, right.frame.width, accuracy: 3, "bottom row panes differ in width")
        XCTAssertEqual(perspective.frame.height, front.frame.height, accuracy: 3, "left column panes differ in height")
        XCTAssertEqual(top.frame.height, right.frame.height, accuracy: 3, "right column panes differ in height")
        XCTAssertEqual(perspective.frame.width, halfWidth, accuracy: 4, "left pane is not half width")
        XCTAssertEqual(perspective.frame.height, halfHeight, accuracy: 4, "top pane is not half height")
        XCTAssertLessThanOrEqual(perspective.frame.maxX, top.frame.minX + 2, "top panes overlap")
        XCTAssertLessThanOrEqual(perspective.frame.maxY, front.frame.minY + 2, "left panes overlap")
        XCTAssertGreaterThanOrEqual(perspective.frame.minX, viewport.frame.minX - 1)
        XCTAssertLessThanOrEqual(right.frame.maxX, viewport.frame.maxX + 1)
        XCTAssertLessThanOrEqual(right.frame.maxY, viewport.frame.maxY + 1)
    }

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func waitForDisappearance(
        _ element: XCUIElement,
        timeout: TimeInterval,
        _ message: String
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, message)
    }
}
