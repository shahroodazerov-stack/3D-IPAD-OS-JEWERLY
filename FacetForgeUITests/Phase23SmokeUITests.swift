import XCTest

/// Phase 23's smoke suite. It drives the same document commands a jeweller
/// uses: create, load the fixture, select, orbit, drag the gizmo, undo that
/// drag, drag again, save and reopen. Every step leaves a screenshot, and the
/// per-edit history counts are proven by `Phase23EditIntegrationTests`.
final class Phase23SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCreateLoadOrbitSelectUndoDragSaveReopen() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()

        let viewport = element("shell.viewport", app)
        XCTAssertTrue(viewport.waitForExistence(timeout: 30), "shell viewport did not appear")
        let status = element("shell.document.status", app)
        XCTAssertTrue(status.waitForExistence(timeout: 15), "document status did not appear")
        attach(app, "phase23-launch")

        // Create a document, then load the bench fixture.
        choose("New document", app: app)
        waitForLabel(status, "New document")
        XCTAssertTrue(
            waitForDisappearance(element("gumball.position", app), timeout: 10),
            "a new empty document still showed a gizmo"
        )
        attach(app, "phase23-new-document")

        choose("Load fixture", app: app)
        waitForLabel(status, "Fixture loaded")
        let readout = element("gumball.position", app)
        XCTAssertTrue(readout.waitForExistence(timeout: 15), "fixture gizmo did not appear")
        let fixture = try XCTUnwrap(parsePosition(readout.label), readout.label)
        XCTAssertEqual(fixture.x, 0, accuracy: 1e-6)
        XCTAssertEqual(fixture.y, 40, accuracy: 1e-6)
        XCTAssertEqual(fixture.z, 0, accuracy: 1e-6)
        attach(app, "phase23-fixture")

        // Clear the selection on empty viewport space, then select the stone by
        // tapping the point the gizmo pivot occupied.
        let metal = element("shell.viewport.metal", app)
        XCTAssertTrue(metal.waitForExistence(timeout: 15), "Metal viewport did not appear")
        let pivot = element("gumball.pivot", app)
        XCTAssertTrue(pivot.waitForExistence(timeout: 10), "gumball pivot is missing")
        let stone = normalizedPoint(
            of: pivot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).screenPoint,
            in: metal
        )
        metal.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).tap()
        XCTAssertTrue(
            waitForDisappearance(readout, timeout: 10),
            "tapping empty space did not clear the selection"
        )
        metal.coordinate(withNormalizedOffset: stone).tap()
        XCTAssertTrue(readout.waitForExistence(timeout: 10), "tapping the stone did not select it")
        XCTAssertTrue(
            waitForPosition(readout, timeout: 10) { position in
                abs(position.x) < 1e-6 && abs(position.y - 40) < 1e-6
            } != nil,
            "the reselected stone moved"
        )
        attach(app, "phase23-selected")

        // Orbit is a camera gesture and must not become an edit.
        let camera = element("shell.viewport.camera", app)
        XCTAssertTrue(camera.waitForExistence(timeout: 10), "camera HUD did not appear")
        let cameraBefore = camera.label
        let orbitStart = metal.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.74))
        let orbitEnd = metal.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.70))
        orbitStart.press(forDuration: 0.1, thenDragTo: orbitEnd)
        XCTAssertTrue(
            waitForCondition(timeout: 10, { camera.label != cameraBefore }),
            "orbit did not change the camera"
        )
        attach(app, "phase23-orbit")

        // Drag the X handle by its projected ten-millimetre length.
        dragXHandle(metal: metal, app: app)
        guard let moved = waitForPosition(readout, timeout: 20, matching: { abs($0.x - 10) < 1e-3 }) else {
            return XCTFail("the drag did not land on X 10; readout is '\(readout.label)'")
        }
        XCTAssertEqual(moved.x, 10, accuracy: 1e-6)
        XCTAssertEqual(moved.y, 40, accuracy: 1e-6)
        attach(app, "phase23-drag-committed")

        // One document undo reverts that drag, not the selection or camera.
        choose("Undo", app: app)
        XCTAssertNotNil(
            waitForPosition(readout, timeout: 15, matching: { abs($0.x) < 1e-6 }),
            "one undo did not restore X 0; readout is '\(readout.label)'"
        )
        attach(app, "phase23-undo")

        // Drag again and save the committed transform, then reopen it.
        dragXHandle(metal: metal, app: app)
        XCTAssertNotNil(
            waitForPosition(readout, timeout: 20, matching: { abs($0.x - 10) < 1e-3 }),
            "the second drag did not land on X 10; readout is '\(readout.label)'"
        )
        choose("Save", app: app)
        waitForLabel(status, "Saved")
        attach(app, "phase23-saved")

        choose("Reopen", app: app)
        waitForLabel(status, "Reopened")
        XCTAssertNotNil(
            waitForPosition(readout, timeout: 15, matching: { abs($0.x - 10) < 1e-3 }),
            "reopen lost the committed transform; readout is '\(readout.label)'"
        )
        attach(app, "phase23-reopened")
    }

    // MARK: - Document commands

    @MainActor
    private func choose(_ title: String, app: XCUIApplication) {
        let identifier: String
        switch title {
        case "New document": identifier = "shell.document.new"
        case "Load fixture": identifier = "shell.document.fixture"
        case "Save": identifier = "shell.document.save"
        case "Reopen": identifier = "shell.document.reopen"
        case "Undo": identifier = "shell.document.undo"
        default: identifier = title
        }
        let button = element(identifier, app)
        XCTAssertTrue(button.waitForExistence(timeout: 15), "document command '\(title)' did not appear")
        XCTAssertTrue(button.isHittable, "document command '\(title)' is not hittable")
        button.tap()
    }

    // MARK: - Gizmo drag

    @MainActor
    private func dragXHandle(metal: XCUIElement, app: XCUIApplication) {
        let pivot = element("gumball.pivot", app)
        let handle = element("gumball.handle.x", app)
        XCTAssertTrue(pivot.waitForExistence(timeout: 10), "gumball pivot is missing")
        XCTAssertTrue(handle.waitForExistence(timeout: 10), "gumball X handle is missing")

        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let pivotPoint = pivot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let delta = CGVector(
            dx: pivotPoint.screenPoint.x - start.screenPoint.x,
            dy: pivotPoint.screenPoint.y - start.screenPoint.y
        )
        XCTAssertGreaterThan(
            sqrt(delta.dx * delta.dx + delta.dy * delta.dy),
            8,
            "the X handle has no usable screen length"
        )
        let target = start.withOffset(CGVector(dx: delta.dx * 1.02, dy: delta.dy * 1.02))
        start.press(forDuration: 0.15, thenDragTo: target)
    }

    // MARK: - Geometry and waits

    private struct Position {
        var x: Double
        var y: Double
        var z: Double
    }

    private func parsePosition(_ label: String) -> Position? {
        let pattern = "([XYZ])\\s+(-?[0-9]+(?:\\.[0-9]+)?)"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(label.startIndex..., in: label)
        var values: [String: Double] = [:]
        for match in expression.matches(in: label, range: range) {
            guard match.numberOfRanges == 3,
                  let axisRange = Range(match.range(at: 1), in: label),
                  let valueRange = Range(match.range(at: 2), in: label),
                  let value = Double(label[valueRange])
            else { continue }
            values[String(label[axisRange])] = value
        }
        guard let x = values["X"], let y = values["Y"], let z = values["Z"] else { return nil }
        return Position(x: x, y: y, z: z)
    }

    private func waitForPosition(
        _ element: XCUIElement,
        timeout: TimeInterval,
        matching predicate: (Position) -> Bool = { _ in true }
    ) -> Position? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let position = parsePosition(element.label), predicate(position) {
                return position
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return parsePosition(element.label).flatMap { predicate($0) ? $0 : nil }
    }

    private func waitForCondition(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    @MainActor
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ fragment: String) {
        XCTAssertTrue(
            waitForCondition(timeout: 15, { element.label.contains(fragment) }),
            "'\(element.label)' did not contain '\(fragment)'"
        )
    }

    @MainActor
    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func normalizedPoint(of screenPoint: CGPoint, in element: XCUIElement) -> CGVector {
        let frame = element.frame
        guard frame.width > 1, frame.height > 1 else { return CGVector(dx: 0.5, dy: 0.5) }
        return CGVector(
            dx: (screenPoint.x - frame.minX) / frame.width,
            dy: (screenPoint.y - frame.minY) / frame.height
        )
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
