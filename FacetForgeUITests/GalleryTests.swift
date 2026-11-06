import XCTest

final class GalleryTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGalleryExposesEveryPrimitiveSectionAndArchivesScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        let open = app.buttons["Open component gallery"]
        XCTAssertTrue(open.waitForExistence(timeout: 15), "gallery entry point is missing")
        open.tap()

        XCTAssertTrue(app.staticTexts["Component gallery"].waitForExistence(timeout: 10))

        let sections = [
            "gallery.section.buttons",
            "gallery.section.chips",
            "gallery.section.fields",
            "gallery.section.slider",
            "gallery.section.segmented",
            "gallery.section.sheet",
            "gallery.section.panel",
            "gallery.section.list",
            "gallery.section.toast",
            "gallery.section.tooltip",
            "gallery.section.toolbar",
            "gallery.section.empty",
        ]

        for identifier in sections {
            let section = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(section.exists, "gallery section \(identifier) is missing")
        }

        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "component-gallery-top"
        top.lifetime = .keepAlways
        add(top)

        app.swipeUp()
        app.swipeUp()

        let bottom = XCTAttachment(screenshot: app.screenshot())
        bottom.name = "component-gallery-bottom"
        bottom.lifetime = .keepAlways
        add(bottom)
    }
}
