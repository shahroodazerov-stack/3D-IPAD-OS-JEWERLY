import UIKit
import XCTest
@testable import FacetForge

final class AppIdentityTests: XCTestCase {
    func testBundleIdentifierMatchesTheShippingTarget() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, AppIdentity.bundleIdentifier)
    }

    func testProductNameAndTagline() {
        XCTAssertEqual(AppIdentity.displayName, "FacetForge")
        XCTAssertEqual(AppIdentity.tagline, "iPad CAD for jewellers")
    }

    func testPhaseFourIsTheActiveShell() {
        XCTAssertEqual(AppIdentity.phase, 4)
        XCTAssertEqual(AppIdentity.phaseLabel, "Phase 4 · adaptive shell")
    }

    func testTheHostAppSupportsTheIPadLayout() {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
    }
}
