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

    func testPhaseThirteenIsTheRenderHost() {
        XCTAssertEqual(AppIdentity.phase, 13)
        XCTAssertEqual(AppIdentity.phaseLabel, "Phase 13 · render host")
    }

    func testTheHostAppSupportsTheIPadLayout() {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
    }
}
