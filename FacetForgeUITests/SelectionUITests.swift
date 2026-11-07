import XCTest

/// Phase 17's acceptance. The simulator has no Shift key, so the Multi chip is
/// the touch equivalent the test drives; the pick itself is the Phase 14 ID
/// buffer through the same tap path a jeweller uses.
final class SelectionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testFilterMultiMarqueeAndIsolate() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()

        let metal = element("shell.viewport.metal", app)
        XCTAssertTrue(metal.waitForExistence(timeout: 30), "Metal viewport did not appear")

        let summary = element("selection.summary", app)
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "inspector selection summary missing")
        XCTAssertTrue(summary.label.contains("Stone"), "the bench sample should open with the stone selected")

        // Filtered selection: the stone filter rejects the shank click, so the
        // pick resolves to nothing and the selection clears instead of falling
        // through to the metal.
        element("selection.filter.stone", app).tap()
        tapShank(metal)
        waitForLabel(summary, "No selection", "the stone filter let the shank through")

        // The same click without the filter must select the shank. This is the
        // Phase 14 pick actually bound to selection.
        element("selection.filter.solid", app).tap()
        tapShank(metal)
        waitForLabel(summary, "Shank", "the shank click did not select")

        // Zoom out before the window tests. At the default framing the ring is
        // wider than the portrait pane and the stone sits close to the top
        // overlay, so a box that contains every vertex is hard to aim by hand.
        // One pinch gives both objects a margin, and the marquee still tests
        // full containment rather than a bounding-box overlap.
        metal.pinch(withScale: 0.7, velocity: -1)

        // Multi-select with the touch equivalent of Shift: keep the shank and
        // add the stone with a box around it.
        element("selection.filter.all", app).tap()
        element("selection.multi", app).tap()
        drag(metal, from: CGVector(dx: 0.35, dy: 0.42), to: CGVector(dx: 0.65, dy: 0.20))
        waitForLabel(summary, "2 selected", "multi-select marquee did not add the stone")

        // The selection sets panel stores the pair and recalls it.
        element("selection.saveSet", app).tap()
        XCTAssertTrue(
            element("selection.set.0", app).waitForExistence(timeout: 10),
            "saving a selection set did not add a row"
        )
        element("selection.multi", app).tap()

        // Marquee replace: a box over the whole viewport with the solid filter
        // selects the shank alone, proving the marquee is a real window test
        // and not a bounding-box intersection that would also catch the stone.
        element("selection.filter.solid", app).tap()
        drag(metal, from: CGVector(dx: 0.05, dy: 0.20), to: CGVector(dx: 0.95, dy: 0.95))
        waitForLabel(summary, "Shank", "marquee replace did not isolate the shank")

        // Isolate hides the stone; Show all brings it back.
        element("selection.isolate", app).tap()
        let visibility = element("selection.visibility", app)
        XCTAssertTrue(visibility.waitForExistence(timeout: 10), "visibility readout missing")
        XCTAssertTrue(
            visibility.label.contains("1 hidden"),
            "isolate did not hide the stone: '\(visibility.label)'"
        )

        let isolatedShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        isolatedShot.name = "phase17-isolated-shank"
        isolatedShot.lifetime = .keepAlways
        add(isolatedShot)

        element("selection.showAll", app).tap()
        XCTAssertTrue(
            waitForLabel(visibility, "0 hidden", "Show all did not restore the stone")
        )

        let restoredShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        restoredShot.name = "phase17-show-all"
        restoredShot.lifetime = .keepAlways
        add(restoredShot)
    }

    // MARK: - Helpers

    @discardableResult
    private func waitForLabel(
        _ element: XCUIElement,
        _ expected: String,
        _ message: String,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("\(message): label was '\(element.label)'")
            return false
        }
        return true
    }

    private func tapShank(_ metal: XCUIElement) {
        metal.coordinate(withNormalizedOffset: CGVector(dx: 0.145, dy: 0.55)).tap()
    }

    private func drag(_ metal: XCUIElement, from: CGVector, to: CGVector) {
        metal.coordinate(withNormalizedOffset: from)
            .press(forDuration: 0.15, thenDragTo: metal.coordinate(withNormalizedOffset: to))
    }

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
