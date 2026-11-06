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

    func testPhaseSixIsTheCurveKernel() {
        XCTAssertEqual(AppIdentity.phase, 6)
        XCTAssertEqual(AppIdentity.phaseLabel, "Phase 6 · curve kernel")
    }

    func testTheHostAppSupportsTheIPadLayout() {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
    }
}
