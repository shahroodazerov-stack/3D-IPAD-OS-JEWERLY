import XCTest
@testable import FacetForge

/// Phase 16 is proven headlessly: thirty snap cases, one per kind and three per
/// kind, then the hover entry point timed at three zoom levels. Every candidate
/// is a world point projected through the same camera the viewport draws.
final class Phase16SnappingTests: XCTestCase {
    private let camera = FFCamera.standard
    private let viewport = Vec2(x: 800, y: 600)

    private struct SnapCase {
        let name: String
        let geometry: FFSnapGeometry
        let reference: Vec3?
        let hover: Vec2
        let kind: FFSnapKind
        let position: Vec3?
        let angleMultiple: Bool
    }

    // MARK: - Thirty cases

    func testThirtyHeadlessSnapCases() {
        let cases = snapCases()
        XCTAssertEqual(cases.count, 30)

        for testCase in cases {
            let result = FFSnapResolver.resolve(
                hover: testCase.hover,
                reference: testCase.reference,
                geometry: testCase.geometry,
                camera: camera,
                viewport: viewport
            )
            guard let result else {
                XCTFail("\(testCase.name): no snapshot candidate at all")
                continue
            }
            XCTAssertEqual(result.best.kind, testCase.kind, "\(testCase.name): wrong snap kind")
            XCTAssertTrue(
                result.markers.contains(where: { $0.kind == testCase.kind }),
                "\(testCase.name): the marker list omits the winning kind"
            )

            if let expected = testCase.position {
                XCTAssertEqual(result.best.position.x, expected.x, accuracy: 1e-6, testCase.name)
                XCTAssertEqual(result.best.position.y, expected.y, accuracy: 1e-6, testCase.name)
                XCTAssertEqual(result.best.position.z, expected.z, accuracy: 1e-6, testCase.name)
            }

            if testCase.angleMultiple, let reference = testCase.reference {
                let origin = screen(reference)
                let direction = result.best.screen - origin
                let degrees = atan2(direction.y, direction.x) * 180 / .pi
                let remainder = abs(degrees.truncatingRemainder(dividingBy: 15))
                XCTAssertTrue(
                    remainder < 1 || abs(remainder - 15) < 1,
                    "\(testCase.name): \(degrees)° is not a 15° multiple"
                )
            }
        }
    }

    private func snapCases() -> [SnapCase] {
        let xEdge = FFSnapSegment(Vec3(x: 0, y: 0, z: 0), Vec3(x: 10, y: 0, z: 0))
        let crossingA = FFSnapSegment(Vec3(x: 0, y: 0, z: 5), Vec3(x: 10, y: 0, z: 5))
        let crossingB = FFSnapSegment(Vec3(x: 3, y: 0, z: 2), Vec3(x: 3, y: 0, z: 12))
        let crossingC = FFSnapSegment(Vec3(x: 0, y: 10, z: 0), Vec3(x: 10, y: 10, z: 0))
        let crossingD = FFSnapSegment(Vec3(x: 2, y: 8, z: 0), Vec3(x: 2, y: 20, z: 0))
        let crossingE = FFSnapSegment(Vec3(x: 0, y: 0, z: 0), Vec3(x: 0, y: 20, z: 0))
        let crossingF = FFSnapSegment(Vec3(x: -6, y: 4, z: 0), Vec3(x: 2, y: 4, z: 0))
        let slant = FFSnapSegment(Vec3(x: -4, y: 2, z: -4), Vec3(x: 4, y: 2, z: 4))
        let vertical = FFSnapSegment(Vec3(x: 0, y: 0, z: 0), Vec3(x: 0, y: 0, z: 12))
        let longDiagonal = FFSnapSegment(Vec3(x: 0, y: 0, z: 0), Vec3(x: 20, y: 10, z: 0))

        let zero = screen(.zero)
        let tan1 = FFSnapCircle(centre: .zero, radius: 10)
        let tan2 = FFSnapCircle(centre: Vec3(x: 0, y: 30, z: 0), radius: 5)
        let tan3 = FFSnapCircle(
            centre: .zero,
            normal: Vec3(x: 1, y: 0, z: 0),
            radius: 6
        )

        return [
            worldCase("vertex 1", points: [FFSnapPoint(Vec3(x: 5, y: 10, z: 0))], world: Vec3(x: 5, y: 10, z: 0), kind: .vertex, position: Vec3(x: 5, y: 10, z: 0)),
            worldCase("vertex 2", points: [FFSnapPoint(Vec3(x: -8, y: 20, z: 4))], world: Vec3(x: -8, y: 20, z: 4), kind: .vertex, position: Vec3(x: -8, y: 20, z: 4)),
            worldCase("vertex 3", points: [FFSnapPoint(Vec3(x: 0, y: 60, z: -10))], world: Vec3(x: 0, y: 60, z: -10), kind: .vertex, position: Vec3(x: 0, y: 60, z: -10)),

            worldCase("endpoint 1", geometry: segments([xEdge]), world: Vec3(x: 10, y: 0, z: 0), kind: .endpoint, position: Vec3(x: 10, y: 0, z: 0)),
            worldCase("endpoint 2", geometry: segments([FFSnapSegment(Vec3(x: -5, y: 3, z: 0), Vec3(x: 5, y: 3, z: 0))]), world: Vec3(x: -5, y: 3, z: 0), kind: .endpoint, position: Vec3(x: -5, y: 3, z: 0)),
            worldCase("endpoint 3", geometry: segments([FFSnapSegment(Vec3(x: 0, y: 10, z: 0), Vec3(x: 0, y: 10, z: 20))]), world: Vec3(x: 0, y: 10, z: 20), kind: .endpoint, position: Vec3(x: 0, y: 10, z: 20)),

            worldCase("midpoint 1", geometry: segments([xEdge]), world: Vec3(x: 5, y: 0, z: 0), kind: .midpoint, position: Vec3(x: 5, y: 0, z: 0)),
            worldCase("midpoint 2", geometry: segments([FFSnapSegment(Vec3(x: 2, y: 4, z: 6), Vec3(x: 12, y: 4, z: 6))]), world: Vec3(x: 7, y: 4, z: 6), kind: .midpoint, position: Vec3(x: 7, y: 4, z: 6)),
            worldCase("midpoint 3", geometry: segments([FFSnapSegment(Vec3(x: 0, y: 0, z: -10), Vec3(x: 0, y: 0, z: 10))]), world: Vec3(x: 0, y: 0, z: 0), kind: .midpoint, position: Vec3(x: 0, y: 0, z: 0)),

            worldCase("centre 1", points: [FFSnapPoint(Vec3(x: 10, y: 10, z: 10), kind: .centre)], world: Vec3(x: 10, y: 10, z: 10), kind: .centre, position: Vec3(x: 10, y: 10, z: 10)),
            worldCase("centre 2", points: [FFSnapPoint(Vec3(x: -20, y: 5, z: 3), kind: .centre)], world: Vec3(x: -20, y: 5, z: 3), kind: .centre, position: Vec3(x: -20, y: 5, z: 3)),
            worldCase("centre 3", geometry: circles([tan2]), world: Vec3(x: 0, y: 30, z: 0), kind: .centre, position: Vec3(x: 0, y: 30, z: 0)),

            worldCase("intersection 1", geometry: segments([crossingA, crossingB]), world: Vec3(x: 3, y: 0, z: 5), kind: .intersection, position: Vec3(x: 3, y: 0, z: 5)),
            worldCase("intersection 2", geometry: segments([crossingC, crossingD]), world: Vec3(x: 2, y: 10, z: 0), kind: .intersection, position: Vec3(x: 2, y: 10, z: 0)),
            worldCase("intersection 3", geometry: segments([crossingE, crossingF]), world: Vec3(x: 0, y: 4, z: 0), kind: .intersection, position: Vec3(x: 0, y: 4, z: 0)),

            worldCase("on curve 1", geometry: segments([xEdge]), world: Vec3(x: 3, y: 0, z: 0), kind: .onCurve, position: Vec3(x: 3, y: 0, z: 0)),
            worldCase("on curve 2", geometry: segments([FFSnapSegment(Vec3(x: 0, y: 5, z: 0), Vec3(x: 0, y: 5, z: 10))]), world: Vec3(x: 0, y: 5, z: 3), kind: .onCurve, position: Vec3(x: 0, y: 5, z: 3)),
            worldCase("on curve 3", geometry: segments([slant]), world: Vec3(x: -1, y: 2, z: -1), kind: .onCurve, position: Vec3(x: -1, y: 2, z: -1)),

            worldCase("perpendicular 1", geometry: segments([xEdge]), reference: Vec3(x: 3, y: 8, z: 0), world: Vec3(x: 3, y: 0, z: 0), kind: .perpendicular, position: Vec3(x: 3, y: 0, z: 0)),
            worldCase("perpendicular 2", geometry: segments([vertical]), reference: Vec3(x: -2, y: 0, z: 4), world: Vec3(x: 0, y: 0, z: 4), kind: .perpendicular, position: Vec3(x: 0, y: 0, z: 4)),
            worldCase("perpendicular 3", geometry: segments([longDiagonal]), reference: Vec3(x: 5, y: 5, z: 5), world: Vec3(x: 6, y: 3, z: 0), kind: .perpendicular, position: Vec3(x: 6, y: 3, z: 0)),

            worldCase("tangent 1", geometry: circles([tan1]), reference: Vec3(x: 20, y: 0, z: 0), world: Vec3(x: 5, y: 0, z: 8.660254), kind: .tangent),
            worldCase("tangent 2", geometry: circles([tan2]), reference: Vec3(x: 13, y: 30, z: 0), world: Vec3(x: 1.923077, y: 30, z: 4.615385), kind: .tangent),
            worldCase("tangent 3", geometry: circles([tan3]), reference: Vec3(x: 0, y: 20, z: 0), world: Vec3(x: 0, y: 1.8, z: 5.723638), kind: .tangent),

            worldCase("grid 1", world: Vec3(x: 3.2, y: 0, z: -4.4), kind: .grid, position: Vec3(x: 3, y: 0, z: -4)),
            worldCase("grid 2", world: Vec3(x: -7.6, y: 0, z: 0.6), kind: .grid, position: Vec3(x: -8, y: 0, z: 1)),
            worldCase("grid 3", world: Vec3(x: 12.3, y: 0, z: 19.7), kind: .grid, position: Vec3(x: 12, y: 0, z: 20)),

            screenCase("angle 1", reference: Vec3.zero, hover: zero + Vec2(x: 100, y: 3.49), kind: .angle),
            screenCase("angle 2", reference: Vec3(x: 5, y: 5, z: 5), hover: screen(Vec3(x: 5, y: 5, z: 5)) + Vec2(x: 57.36, y: 55.4), kind: .angle),
            screenCase("angle 3", reference: Vec3(x: -10, y: 0, z: 10), hover: screen(Vec3(x: -10, y: 0, z: 10)) + Vec2(x: -61.8, y: 32.86), kind: .angle)
        ]
    }

    // MARK: - Tangency and marker evidence

    func testTangentPointsAreExact() {
        let circle = FFSnapCircle(centre: .zero, radius: 10)
        let reference = Vec3(x: 20, y: 0, z: 0)
        let expected = [
            Vec3(x: 5, y: 0, z: 8.660254037844),
            Vec3(x: 5, y: 0, z: -8.660254037844)
        ]

        for point in expected {
            let result = FFSnapResolver.resolve(
                hover: screen(point),
                reference: reference,
                geometry: circles([circle]),
                camera: camera,
                viewport: viewport
            )
            XCTAssertEqual(result?.best.kind, FFSnapKind.tangent)
            XCTAssertEqual(result?.best.position.x ?? .nan, point.x, accuracy: 1e-6)
            XCTAssertEqual(result?.best.position.z ?? .nan, point.z, accuracy: 1e-6)
        }
    }

    func testMarkersAppearWithinFortyMillisecondsAtThreeZooms() throws {
        let scene = FFViewportScene.jewelleryDemo
        let stone = try XCTUnwrap(scene.nodes.first(where: \.isSelected))
        let world = Vec3(x: 6, y: 40, z: 0)

        for distance in [150.0, 250.0, 400.0] {
            let camera = FFCamera(distance: distance)
            let hover = try XCTUnwrap(camera.screenPoint(for: world, viewport: viewport))
            let start = Date()
            let markers = FFSnapHover.markers(
                hover: hover,
                scene: scene,
                selectedID: stone.id,
                reference: nil,
                camera: camera,
                viewport: viewport
            )
            let elapsed = Date().timeIntervalSince(start)

            XCTAssertLessThan(elapsed, 0.04, "hover took \(elapsed * 1_000) ms at \(distance) mm")
            XCTAssertTrue(markers.contains(where: { $0.kind == .vertex }), "no vertex marker at \(distance) mm")
            XCTAssertEqual(markers.first(where: \.isBest)?.kind, FFSnapKind.vertex)
            XCTAssertEqual(markers.first(where: \.isBest)?.label, "Vertex")
        }
    }

    func testSameWorldPointStillSnapsAfterZoom() throws {
        let scene = FFViewportScene.jewelleryDemo
        let stone = try XCTUnwrap(scene.nodes.first(where: \.isSelected))
        let world = Vec3(x: 6, y: 40, z: 0)

        for distance in [150.0, 250.0, 400.0] {
            let camera = FFCamera(distance: distance)
            let hover = try XCTUnwrap(camera.screenPoint(for: world, viewport: viewport))
            let markers = FFSnapHover.markers(
                hover: hover,
                scene: scene,
                selectedID: stone.id,
                reference: nil,
                camera: camera,
                viewport: viewport
            )
            let best = try XCTUnwrap(markers.first(where: \.isBest))
            XCTAssertEqual(best.kind, .vertex, "the vertex stopped snapping at \(distance) mm")
            XCTAssertEqual(best.screen.x, hover.x, accuracy: 0.5)
            XCTAssertEqual(best.screen.y, hover.y, accuracy: 0.5)
        }
    }

    // MARK: - Helpers

    private func worldCase(
        _ name: String,
        points: [FFSnapPoint] = [],
        geometry: FFSnapGeometry = FFSnapGeometry(),
        reference: Vec3? = nil,
        world: Vec3,
        kind: FFSnapKind,
        position: Vec3? = nil
    ) -> SnapCase {
        var shape = geometry
        shape.points.append(contentsOf: points)
        return SnapCase(
            name: name,
            geometry: shape,
            reference: reference,
            hover: screen(world),
            kind: kind,
            position: position,
            angleMultiple: false
        )
    }

    private func screenCase(
        _ name: String,
        geometry: FFSnapGeometry = FFSnapGeometry(),
        reference: Vec3?,
        hover: Vec2,
        kind: FFSnapKind
    ) -> SnapCase {
        SnapCase(
            name: name,
            geometry: geometry,
            reference: reference,
            hover: hover,
            kind: kind,
            position: nil,
            angleMultiple: kind == .angle
        )
    }

    private func segments(_ segments: [FFSnapSegment]) -> FFSnapGeometry {
        var geometry = FFSnapGeometry()
        geometry.segments = segments
        return geometry
    }

    private func circles(_ circles: [FFSnapCircle]) -> FFSnapGeometry {
        var geometry = FFSnapGeometry()
        geometry.circles = circles
        return geometry
    }

    private func screen(_ world: Vec3) -> Vec2 {
        guard let point = camera.screenPoint(for: world, viewport: viewport) else {
            fatalError("camera cannot project \(world)")
        }
        return point
    }
}
