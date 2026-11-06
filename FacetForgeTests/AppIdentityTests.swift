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

    func testPhaseTwoIsTheActiveGate() {
        XCTAssertEqual(AppIdentity.phase, 999)
        XCTAssertEqual(AppIdentity.phaseLabel, "Phase 2 · behaviour gate")
    }

    func testTheHostAppSupportsTheIPadLayout() {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
    }
}
