import XCTest

/// Phase 20's panel acceptance. The layer panel is the only place a jeweller
/// meets the document's layers, so the test drives the same chips a finger
/// does: pick the Stones layer, select by layer, hide it, then lock Metal and
/// prove the assignment action refuses to fire.
final class LayerPanelUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testLayerPanelSelectsHidesAndRejectsLockedEdits() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()

        let metal = element("shell.viewport.metal", app)
        XCTAssertTrue(metal.waitForExistence(timeout: 30), "Metal viewport did not appear")

        let metalRow = element("layer.row.0", app)
        let stonesRow = element("layer.row.1", app)
        XCTAssertTrue(metalRow.waitForExistence(timeout: 15), "the layer panel is missing")
        XCTAssertTrue(metalRow.label.contains("Metal"), "row 0 was '\(metalRow.label)'")
        XCTAssertTrue(stonesRow.label.contains("Stones"), "row 1 was '\(stonesRow.label)'")

        let current = element("layer.current", app)
        XCTAssertTrue(current.label.contains("Metal"), "the bench sample should open on Metal")

        // Select by layer: making Stones current and selecting it must select
        // the stone, not the whole ring.
        stonesRow.tap()
        waitForLabel(current, "Stones", "tapping the Stones row did not make it current")
        element("layer.select").tap()
        let summary = element("selection.summary", app)
        waitForLabel(summary, "Stone", "Select did not select the Stones layer")

        // Hide the layer. The stone stays selected but leaves the drawing and
        // the pick buffer; the visibility readout names it.
        element("layer.visible.1", app).tap()
        let visibility = element("selection.visibility", app)
        waitForLabel(visibility, "1 hidden", "hiding Stones did not hide the stone")

        let hiddenShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        hiddenShot.name = "phase20-hidden-layer"
        hiddenShot.lifetime = .keepAlways
        add(hiddenShot)

        element("layer.visible.1", app).tap()
        waitForLabel(visibility, "0 hidden", "showing Stones did not restore the stone")

        // Lock Metal, make it current and select its node. Moving that node
        // into the current (locked) layer is an edit the panel must refuse.
        element("layer.lock.0", app).tap()
        metalRow.tap()
        element("layer.select").tap()
        waitForLabel(summary, "Shank", "Select did not select the Metal layer")

        let assign = element("layer.assign", app)
        XCTAssertTrue(assign.exists, "the assignment action is missing")
        XCTAssertFalse(
            assign.isEnabled,
            "a locked current layer still offered to accept an assignment"
        )

        let lockedShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        lockedShot.name = "phase20-locked-layer"
        lockedShot.lifetime = .keepAlways
        add(lockedShot)

        element("layer.lock.0", app).tap()
        XCTAssertTrue(assign.isEnabled, "unlocking the layer did not restore assignment")
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

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
