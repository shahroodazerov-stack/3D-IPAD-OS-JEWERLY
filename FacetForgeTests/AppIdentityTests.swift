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

    func testPhaseNineIsTheMetalViewportBootstrap() {
        XCTAssertEqual(AppIdentity.phase, 9)
        XCTAssertEqual(AppIdentity.phaseLabel, "Phase 9 · metal viewport")
    }

    func testTheHostAppSupportsTheIPadLayout() {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
    }
}
