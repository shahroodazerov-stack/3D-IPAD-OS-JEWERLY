import XCTest

final class AdaptiveShellTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testFiveWidthsStayUnclippedAndDoNotOverlap() throws {
        let app = launchLayoutLab()
        let widths: [CGFloat] = [640, 700, 820, 1024, 1366]

        for width in widths {
            let chip = app.buttons["layout.width.\(Int(width))"]
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "width chip \(Int(width)) is missing")
            chip.tap()

            let shell = element("shell", app)
            let tools = element("shell.tools", app)
            let viewport = element("shell.viewport", app)
            let inspector = element("shell.inspector", app)

            XCTAssertTrue(shell.waitForExistence(timeout: 5), "shell missing at \(Int(width)) pt")
            XCTAssertTrue(tools.exists, "tools zone missing at \(Int(width)) pt")
            XCTAssertTrue(viewport.exists, "viewport zone missing at \(Int(width)) pt")
            XCTAssertTrue(inspector.exists, "inspector zone missing at \(Int(width)) pt")

            XCTAssertEqual(shell.frame.width, width, accuracy: 3, "shell did not render at \(Int(width)) pt")
            XCTAssertGreaterThan(tools.frame.width, 0)
            XCTAssertGreaterThan(viewport.frame.width, 200)
            XCTAssertGreaterThan(inspector.frame.width, 0)

            XCTAssertGreaterThanOrEqual(tools.frame.minX, shell.frame.minX - 1)
            XCTAssertLessThanOrEqual(tools.frame.maxX, viewport.frame.minX + 1, "tools overlap viewport")
            XCTAssertLessThanOrEqual(viewport.frame.maxX, inspector.frame.minX + 1, "viewport overlaps inspector")
            XCTAssertLessThanOrEqual(inspector.frame.maxX, shell.frame.maxX + 1, "inspector escapes shell")

            let openGallery = app.buttons["shell.openGallery"]
            XCTAssertTrue(openGallery.exists, "app bar control missing at \(Int(width)) pt")
            XCTAssertGreaterThanOrEqual(openGallery.frame.height, 44, "app bar target below 44 pt")
            XCTAssertGreaterThanOrEqual(openGallery.frame.minX, shell.frame.minX - 1)
            XCTAssertLessThanOrEqual(openGallery.frame.maxX, shell.frame.maxX + 1)

            let bandWidth = app.textFields["Band width"]
            XCTAssertTrue(bandWidth.exists, "band-width field missing at \(Int(width)) pt")
            XCTAssertGreaterThanOrEqual(bandWidth.frame.minX, inspector.frame.minX - 1, "field clipped at left")
            XCTAssertLessThanOrEqual(bandWidth.frame.maxX, inspector.frame.maxX + 1, "field clipped at right")

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "adaptive-shell-\(Int(width))"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    @MainActor
    func testCollapsiblePanelsReturnTheirWidthToTheViewport() throws {
        let app = launchLayoutLab()

        XCTAssertTrue(app.buttons["layout.width.820"].waitForExistence(timeout: 5))
        app.buttons["layout.width.820"].tap()

        let viewportBefore = element("shell.viewport", app)
        XCTAssertTrue(viewportBefore.waitForExistence(timeout: 5))
        let before = viewportBefore.frame.width

        let hideInspector = app.buttons["Hide inspector"]
        XCTAssertTrue(hideInspector.waitForExistence(timeout: 5))
        hideInspector.tap()

        XCTAssertFalse(element("shell.inspector", app).waitForExistence(timeout: 2))
        let afterInspector = element("shell.viewport", app)
        XCTAssertTrue(afterInspector.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(afterInspector.frame.width, before + 200, "inspector width did not return to the viewport")

        let showInspector = app.buttons["Show inspector"]
        XCTAssertTrue(showInspector.waitForExistence(timeout: 3))
        showInspector.tap()
        XCTAssertTrue(element("shell.inspector", app).waitForExistence(timeout: 3))

        let hideTools = app.buttons["Hide tools"]
        XCTAssertTrue(hideTools.waitForExistence(timeout: 5))
        hideTools.tap()
        XCTAssertFalse(element("shell.tools", app).waitForExistence(timeout: 2))

        let showTools = app.buttons["Show tools"]
        XCTAssertTrue(showTools.waitForExistence(timeout: 3))
        showTools.tap()
        XCTAssertTrue(element("shell.tools", app).waitForExistence(timeout: 3))

        let restored = XCTAttachment(screenshot: app.screenshot())
        restored.name = "adaptive-shell-restored"
        restored.lifetime = .keepAlways
        add(restored)
    }

    @MainActor
    private func launchLayoutLab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-FFLayoutLab"]
        app.launch()
        XCTAssertTrue(
            element("layoutLab.title", app).waitForExistence(timeout: 30),
            "layout laboratory did not launch. Hierarchy:\n\(app.debugDescription)"
        )
        return app
    }

    private func element(_ identifier: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
