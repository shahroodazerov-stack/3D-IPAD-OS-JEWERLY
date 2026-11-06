import XCTest
@testable import FacetForge

final class CameraNavigationTests: XCTestCase {
    private let viewport = Vec2(x: 1_024, y: 768)

    func testNamedViewsCoverSevenDistinctOrientations() {
        XCTAssertEqual(FFNamedView.allCases.count, 7)
        XCTAssertEqual(Set(FFNamedView.allCases.map(\.rawValue)).count, 7)

        for view in FFNamedView.allCases {
            var camera = FFCamera.standard
            camera.apply(view)

            XCTAssertEqual(camera.yaw, view.yaw, accuracy: 1e-12, view.rawValue)
            XCTAssertEqual(camera.pitch, view.pitch, accuracy: 1e-12, view.rawValue)
            XCTAssertEqual(FFCameraNavigation.namedView(for: camera)?.rawValue, view.rawValue)
        }
    }

    func testNamedViewsPointTheEyeAtTheExpectedFace() throws {
        let expectations: [(FFNamedView, (Vec3) -> Bool)] = [
            (.front, { $0.z > 0.99 }),
            (.back, { $0.z < -0.99 }),
            (.right, { $0.x > 0.99 }),
            (.left, { $0.x < -0.99 }),
            (.top, { $0.y > 0.99 }),
            (.bottom, { $0.y < -0.99 }),
            (.iso, { $0.x < 0 && $0.y > 0 && $0.z > 0 }),
        ]

        for (view, matches) in expectations {
            var camera = FFCamera.standard
            camera.apply(view)
            let eye = camera.eyeDirection
            XCTAssertTrue(matches(eye), "\(view.rawValue) eye direction was \(eye)")
        }
    }

    func testNamedViewLabelAndSummaryAreExposedToTheHUD() {
        var camera = FFCamera.standard
        camera.apply(.front)
        XCTAssertTrue(camera.summary.contains("Perspective"), camera.summary)
        XCTAssertTrue(camera.summary.contains("yaw 0°"), camera.summary)
        XCTAssertTrue(camera.summary.contains("pitch 0°"), camera.summary)
        XCTAssertTrue(camera.accessibilityState.contains("projection=perspective"))

        camera.setProjection(.orthographic)
        XCTAssertTrue(camera.summary.contains("Orthographic"), camera.summary)
        XCTAssertTrue(camera.accessibilityState.contains("projection=orthographic"))
    }

    func testAnchoredZoomKeepsTheCursorPointWithinOnePixel() throws {
        var generator = LCG(seed: 0xC0FF_EE00_1234_5678)

        for mode in FFProjectionMode.allCases {
            for factor in [0.5, 0.8, 1.25, 3.0] {
                for _ in 0..<40 {
                    var camera = FFCamera.standard
                    camera.setProjection(mode)
                    let anchor = Vec2(
                        x: generator.next() * viewport.x,
                        y: generator.next() * viewport.y
                    )

                    let world = try XCTUnwrap(
                        camera.pointOnTargetPlane(at: anchor, viewport: viewport),
                        "no anchor point for \(anchor) in \(mode.rawValue)"
                    )
                    camera.zoom(by: factor, around: anchor, viewport: viewport)

                    let projected = try XCTUnwrap(
                        camera.screenPoint(for: world, viewport: viewport),
                        "anchored point fell behind the eye in \(mode.rawValue)"
                    )
                    XCTAssertEqual(projected.x, anchor.x, accuracy: 1, "\(mode.rawValue) x at \(anchor)")
                    XCTAssertEqual(projected.y, anchor.y, accuracy: 1, "\(mode.rawValue) y at \(anchor)")
                }
            }
        }
    }

    func testAnchoredZoomAtTheCentreLeavesTheTargetStill() {
        for mode in FFProjectionMode.allCases {
            var camera = FFCamera.standard
            camera.setProjection(mode)
            let target = camera.target

            camera.zoom(
                by: 2,
                around: Vec2(x: viewport.x * 0.5, y: viewport.y * 0.5),
                viewport: viewport
            )

            XCTAssertEqual(camera.target.x, target.x, accuracy: 1e-9, mode.rawValue)
            XCTAssertEqual(camera.target.y, target.y, accuracy: 1e-9, mode.rawValue)
            XCTAssertEqual(camera.target.z, target.z, accuracy: 1e-9, mode.rawValue)
        }

        var perspective = FFCamera.standard
        perspective.zoom(by: 2, around: Vec2(x: 512, y: 384), viewport: viewport)
        XCTAssertEqual(perspective.distance, 75, accuracy: 1e-9)

        var orthographic = FFCamera.standard
        orthographic.setProjection(.orthographic)
        orthographic.zoom(by: 2, around: Vec2(x: 512, y: 384), viewport: viewport)
        XCTAssertEqual(orthographic.orthographicHeight, 45, accuracy: 1e-9)
    }

    func testZoomIsIgnoredOutsideTheDocumentedFactorBand() {
        var camera = FFCamera.standard
        FFCameraNavigation.zoom(
            &camera,
            factor: 0.01,
            around: Vec2(x: 100, y: 100),
            viewport: viewport
        )
        XCTAssertEqual(camera.distance, 150, accuracy: 1e-12)

        FFCameraNavigation.zoom(
            &camera,
            factor: 10,
            around: Vec2(x: 100, y: 100),
            viewport: viewport
        )
        XCTAssertEqual(camera.distance, 150, accuracy: 1e-12)
    }

    func testZoomAtTheDistanceLimitRemainsAnchored() throws {
        var camera = FFCamera.standard
        camera.dolly(by: 1_000)
        XCTAssertEqual(camera.distance, FFCamera.minimumDistance, accuracy: 1e-12)

        let anchor = Vec2(x: 40, y: 720)
        let world = try XCTUnwrap(camera.pointOnTargetPlane(at: anchor, viewport: viewport))
        camera.zoom(by: 4, around: anchor, viewport: viewport)

        let projected = try XCTUnwrap(camera.screenPoint(for: world, viewport: viewport))
        XCTAssertEqual(projected.x, anchor.x, accuracy: 1)
        XCTAssertEqual(projected.y, anchor.y, accuracy: 1)
        XCTAssertEqual(camera.distance, FFCamera.minimumDistance, accuracy: 1e-12)
    }

    func testOrbitConvertsPointsIntoTheDocumentedRadiansAndClamps() {
        var camera = FFCamera.standard
        let yaw = camera.yaw
        let pitch = camera.pitch

        FFCameraNavigation.orbit(&camera, screenDelta: Vec2(x: 100, y: 0))
        XCTAssertEqual(camera.yaw, yaw - 0.8, accuracy: 1e-12)
        XCTAssertEqual(camera.pitch, pitch, accuracy: 1e-12)

        FFCameraNavigation.orbit(&camera, screenDelta: Vec2(x: 0, y: -50))
        XCTAssertEqual(camera.pitch, pitch + 0.4, accuracy: 1e-12)

        FFCameraNavigation.orbit(&camera, screenDelta: Vec2(x: .nan, y: 10))
        XCTAssertEqual(camera.pitch, pitch + 0.4, accuracy: 1e-12)

        FFCameraNavigation.orbit(&camera, screenDelta: Vec2(x: 0, y: -100_000))
        XCTAssertEqual(camera.pitch, FFCamera.pitchLimit, accuracy: 1e-12)
        FFCameraNavigation.orbit(&camera, screenDelta: Vec2(x: 0, y: 100_000))
        XCTAssertEqual(camera.pitch, -FFCamera.pitchLimit, accuracy: 1e-12)
    }

    func testPanTracksTheFingerOneToOneInBothProjections() throws {
        for mode in FFProjectionMode.allCases {
            var camera = FFCamera.standard
            camera.setProjection(mode)
            let anchor = Vec2(x: 300, y: 500)
            let world = try XCTUnwrap(camera.pointOnTargetPlane(at: anchor, viewport: viewport))
            let delta = Vec2(x: 37, y: -19)

            FFCameraNavigation.pan(&camera, screenDelta: delta, viewport: viewport)

            let moved = try XCTUnwrap(camera.screenPoint(for: world, viewport: viewport))
            XCTAssertEqual(moved.x, anchor.x + delta.x, accuracy: 1e-6, mode.rawValue)
            XCTAssertEqual(moved.y, anchor.y + delta.y, accuracy: 1e-6, mode.rawValue)
        }
    }

    func testFrameAllFitsTheJewelleryEnvelopeInView() throws {
        var camera = FFCamera.standard
        FFCameraNavigation.frameAll(&camera)

        XCTAssertEqual(camera.target, FFCameraNavigation.jewelleryBounds.center)

        let bounds = FFCameraNavigation.jewelleryBounds
        for x in [bounds.minimum.x, bounds.maximum.x] {
            for y in [bounds.minimum.y, bounds.maximum.y] {
                for z in [bounds.minimum.z, bounds.maximum.z] {
                    let corner = try XCTUnwrap(
                        camera.screenPoint(for: Vec3(x: x, y: y, z: z), viewport: viewport)
                    )
                    XCTAssertGreaterThanOrEqual(corner.x, 0)
                    XCTAssertLessThanOrEqual(corner.x, viewport.x)
                    XCTAssertGreaterThanOrEqual(corner.y, 0)
                    XCTAssertLessThanOrEqual(corner.y, viewport.y)
                }
            }
        }
    }

    func testFreeOrbitClearsTheNamedViewMatch() {
        var camera = FFCamera.standard
        camera.apply(.front)
        XCTAssertNotNil(FFCameraNavigation.namedView(for: camera))

        FFCameraNavigation.orbit(&camera, screenDelta: Vec2(x: 12, y: 0))
        XCTAssertNil(FFCameraNavigation.namedView(for: camera))
    }

    private struct LCG {
        var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
    }
}
