import XCTest

final class CameraNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNamedViewsOrbitPinchAndProjectionChangeTheCameraState() throws {
        let app = XCUIApplication()
        app.launch()

        let metal = app.descendants(matching: .any)["shell.viewport.metal"]
        XCTAssertTrue(
            metal.waitForExistence(timeout: 20),
            "Metal viewport did not appear. Hierarchy:\n\(app.debugDescription)"
        )

        let cameraLabel = app.staticTexts["shell.viewport.camera"]
        XCTAssertTrue(
            cameraLabel.waitForExistence(timeout: 10),
            "Camera HUD did not appear. Hierarchy:\n\(app.debugDescription)"
        )
        XCTAssertTrue(cameraLabel.label.contains("Iso"), cameraLabel.label)

        let front = app.buttons["shell.viewport.namedView.front"]
        XCTAssertTrue(front.waitForExistence(timeout: 10), "Front named-view chip is missing")
        front.tap()
        XCTAssertTrue(
            wait(until: { cameraLabel.label.contains("Front") }, timeout: 5),
            "Front named view did not update the HUD: \(cameraLabel.label)"
        )

        let frontState = try XCTUnwrap(metal.value as? String, "viewport has no camera state")
        XCTAssertTrue(frontState.contains("yaw=0.0000"), frontState)
        XCTAssertTrue(frontState.contains("pitch=0.0000"), frontState)

        let centre = metal.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let orbitEnd = metal.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5))
        centre.press(forDuration: 0.1, thenDragTo: orbitEnd)
        XCTAssertTrue(
            wait(until: { (metal.value as? String) != frontState }, timeout: 5),
            "One-finger orbit did not change the camera"
        )

        let orbitState = try XCTUnwrap(metal.value as? String)
        let beforePinch = try XCTUnwrap(distance(in: orbitState), "camera state has no distance: \(orbitState)")
        let orbitYaw = try XCTUnwrap(component("yaw", in: orbitState))
        XCTAssertNotEqual(orbitYaw, 0, accuracy: 1e-9, "orbit left yaw at zero")

        metal.pinch(withScale: 2, velocity: 2)
        XCTAssertTrue(
            wait(
                until: {
                    guard let state = metal.value as? String,
                          let current = distance(in: state)
                    else { return false }
                    return current < beforePinch - 1
                },
                timeout: 5
            ),
            "Pinch did not shorten the orbit distance: \(String(describing: metal.value))"
        )

        let projection = app.buttons["shell.viewport.projection"]
        XCTAssertTrue(projection.waitForExistence(timeout: 5))
        projection.tap()
        XCTAssertTrue(
            wait(until: { cameraLabel.label.contains("Orthographic") }, timeout: 5),
            "Projection chip did not switch to orthographic: \(cameraLabel.label)"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "camera-navigation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func wait(until predicate: @escaping () -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return predicate()
    }

    private func distance(in state: String) -> Double? {
        component("distance", in: state)
    }

    private func component(_ name: String, in state: String) -> Double? {
        guard let range = state.range(of: "\(name)=") else { return nil }
        let remainder = state[range.upperBound...]
        return Double(remainder.prefix { $0 != ";" })
    }
}
