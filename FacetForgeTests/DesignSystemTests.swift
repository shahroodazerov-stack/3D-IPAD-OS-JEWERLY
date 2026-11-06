import XCTest
@testable import FacetForge

final class DesignSystemTests: XCTestCase {
    func testEveryTextPairMeetsWCAGAAForNormalText() {
        for (name, foreground, background) in FFPalette.textPairs {
            let ratio = FFColor.contrast(foreground, background)
            XCTAssertGreaterThanOrEqual(
                ratio,
                4.5,
                "\(name) is \(String(format: "%.2f", ratio)):1, below the 4.5:1 WCAG AA minimum"
            )
        }
    }

    func testTheCatalogContainsExactlyTwelvePrimitives() {
        XCTAssertEqual(FFComponentCatalog.names.count, 12)
        XCTAssertEqual(Set(FFComponentCatalog.names).count, 12, "primitive names must be unique")
    }

    func testTheSnapshotFixturesCoverTheCatalog() {
        XCTAssertEqual(FFComponentFixtures.cases.count, FFComponentCatalog.names.count)
        XCTAssertEqual(Set(FFComponentFixtures.cases.map(\.id)).count, 12)
    }

    func testSpacingAndRadiusScalesArePositiveAndOrdered() {
        let spaces = [FFSpace.xxs, FFSpace.xs, FFSpace.sm, FFSpace.md, FFSpace.lg, FFSpace.xl, FFSpace.xxl]
        XCTAssertEqual(spaces, spaces.sorted())
        XCTAssertEqual(Set(spaces).count, spaces.count)
        XCTAssertTrue(spaces.allSatisfy { $0 > 0 })

        let radii = [FFRadius.xs, FFRadius.sm, FFRadius.md, FFRadius.lg]
        XCTAssertEqual(radii, radii.sorted())
        XCTAssertTrue(radii.allSatisfy { $0 > 0 })
    }

    func testSemanticTextRolesAreNotReusedAsFillRoles() {
        XCTAssertNotEqual(FFPalette.textPrimary, FFPalette.accent)
        XCTAssertNotEqual(FFPalette.textWarning, FFPalette.warning)
        XCTAssertNotEqual(FFPalette.textSuccess, FFPalette.success)
        XCTAssertNotEqual(FFPalette.textGem, FFPalette.gem)
    }
}
