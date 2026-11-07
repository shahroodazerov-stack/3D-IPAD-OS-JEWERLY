import XCTest

/// Phase 15's acceptance is the gesture, not the maths: the X handle must move
/// the selection exactly ten millimetres at a 1 mm snap, and a single undo must
/// put the transform back. The projected handle is ten millimetres long by
/// construction, so dragging its tip onto the pivot plus a 2% overshoot is a
/// 10.2 mm gesture that must snap to exactly 10.
final class GumballUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testDragXHandleMovesTenMillimetresAndSingleUndoRestores() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()

        let viewport = element("shell.viewport", app)
        XCTAssertTrue(viewport.waitForExistence(timeout: 30), "shell viewport did not appear")

        let readout = element("gumball.position", app)
        XCTAssertTrue(
            readout.waitForExistence(timeout: 30),
            "gumball overlay did not appear for the selected stone. Hierarchy:\n\(app.debugDescription)"
        )

        guard let before = parsePosition(readout.label) else {
            return XCTFail("could not read the gumball position from '\(readout.label)'")
        }
        XCTAssertEqual(before.x, 0, accuracy: 1e-6)
        XCTAssertEqual(before.y, 40, accuracy: 1e-6)
        XCTAssertEqual(before.z, 0, accuracy: 1e-6)

        let pivot = element("gumball.pivot", app)
        let handle = element("gumball.handle.x", app)
        XCTAssertTrue(pivot.waitForExistence(timeout: 15), "gumball pivot is missing")
        XCTAssertTrue(handle.waitForExistence(timeout: 15), "gumball X handle is missing")

        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let pivotPoint = pivot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let toPivot = CGVector(
            dx: pivotPoint.screenPoint.x - start.screenPoint.x,
            dy: pivotPoint.screenPoint.y - start.screenPoint.y
        )
        XCTAssertGreaterThan(sqrt(toPivot.dx * toPivot.dx + toPivot.dy * toPivot.dy), 8, "the X handle has no usable screen length")
        let target = start.withOffset(
            CGVector(dx: toPivot.dx * 1.02, dy: toPivot.dy * 1.02)
        )
        start.press(forDuration: 0.15, thenDragTo: target)

        guard let after = waitForPosition(readout, timeout: 20, matching: { position in
            abs(abs(position.x - before.x) - 10) < 1e-3
        }) else {
            return XCTFail("X did not land on a 10 mm step; readout is '\(readout.label)'")
        }

        XCTAssertEqual(abs(after.x - before.x), 10, accuracy: 1e-6, "the drag did not snap to exactly 10 mm")
        XCTAssertEqual(after.y, before.y, accuracy: 1e-6, "an X drag moved Y")
        XCTAssertEqual(after.z, before.z, accuracy: 1e-6, "an X drag moved Z")

        let draggedShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        draggedShot.name = "phase15-gumball-after-x-drag"
        draggedShot.lifetime = .keepAlways
        add(draggedShot)

        let undo = app.buttons["gumball.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10), "gumball undo is missing")
        undo.tap()

        guard let restored = waitForPosition(readout, timeout: 15, matching: { position in
            abs(position.x - before.x) < 1e-6
                && abs(position.y - before.y) < 1e-6
                && abs(position.z - before.z) < 1e-6
        }) else {
            return XCTFail("one undo did not restore the prior transform; readout is '\(readout.label)'")
        }
        XCTAssertEqual(restored.x, before.x, accuracy: 1e-6)
        XCTAssertEqual(restored.y, before.y, accuracy: 1e-6)
        XCTAssertEqual(restored.z, before.z, accuracy: 1e-6)

        let restoredShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        restoredShot.name = "phase15-gumball-after-undo"
        restoredShot.lifetime = .keepAlways
        add(restoredShot)
    }

    private struct Position {
        var x: Double
        var y: Double
        var z: Double
    }

    /// Reads `Gumball position X 0.000 · Y 40.000 · Z 0.000`. The readout is an
    /// accessibility label rather than a set of text fields so a VoiceOver user
    /// hears one sentence and the test can parse the same sentence.
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
        matching predicate: (Position) -> Bool
    ) -> Position? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let position = parsePosition(element.label), predicate(position) {
                return position
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return nil
    }

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
