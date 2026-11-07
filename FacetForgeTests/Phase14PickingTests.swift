import Metal
import XCTest
@testable import FacetForge

/// Phase 14 proves picking is not a best guess: a GPU ID buffer and an
/// independent CPU ray oracle agree on 500 synthetic points within one pixel,
/// hidden nodes never reach the buffer, and curves have an analytic six-point
/// fallback because they are not triangles.
final class Phase14PickingTests: XCTestCase {
    private let viewport = Vec2(x: 400, y: 320)

    func testFiveHundredIDBufferPicksMatchTheRayOracleWithinOnePixel() throws {
        let renderer = try makeRenderer()
        let scene = FFViewportScene.jewelleryDemo
        guard let bounds = scene.bounds else { return XCTFail("demo scene has no bounds") }
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.15)

        guard let buffer = renderer.pickBuffer(
            width: Int(viewport.x),
            height: Int(viewport.y),
            camera: camera,
            scene: scene
        ) else {
            return XCTFail("ID pass produced no readback")
        }

        var matched = 0
        var hits = 0
        var failures: [String] = []

        for row in 0..<20 {
            for column in 0..<25 {
                let point = Vec2(x: Double(8 + column * 16), y: Double(8 + row * 16))
                let expected = expectedNode(at: point, scene: scene, camera: camera)
                let picked = FFPickResolver.resolve(buffer: buffer, scene: scene, point: point)
                let expectedRaw = expected.map { UInt32($0 + 1) } ?? 0
                let expectedID = expected.map { scene.nodes[$0].id }
                let raw = buffer.objectID(atX: Int(point.x), y: Int(point.y))

                if expected != nil { hits += 1 }

                if raw == expectedRaw, picked?.nodeID == expectedID {
                    matched += 1
                } else if expected != nil,
                          buffer.objectIDs(
                              aroundX: Int(point.x),
                              y: Int(point.y),
                              radius: 1
                          ).contains(expectedRaw) {
                    // Rasterisation and the ray can differ on the pixel that
                    // owns a silhouette. The acceptance allows one pixel.
                    matched += 1
                } else {
                    failures.append(
                        "point (\(point.x), \(point.y)) expected \(String(describing: expected)) raw \(raw) got \(String(describing: picked?.name))"
                    )
                }
            }
        }

        XCTAssertEqual(matched, 500, failures.prefix(8).joined(separator: "\n"))
        XCTAssertGreaterThanOrEqual(hits, 100, "the sweep barely touched geometry; the oracle would be vacuous")
        XCTAssertNil(renderer.lastCommandBufferError)
    }

    func testHiddenObjectsAreNeverPickedAndIDsStayStable() throws {
        let renderer = try makeRenderer()
        let scene = FFViewportScene.jewelleryDemo
        guard let bounds = scene.bounds else { return XCTFail("demo scene has no bounds") }
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.2)
        guard let stoneIndex = scene.nodes.firstIndex(where: { $0.name == "Stone" }) else {
            return XCTFail("demo scene has no stone")
        }
        let stoneCentre = Vec3(
            x: scene.nodes[stoneIndex].transform.m03,
            y: scene.nodes[stoneIndex].transform.m13,
            z: scene.nodes[stoneIndex].transform.m23
        )
        guard let stonePoint = camera.screenPoint(for: stoneCentre, viewport: viewport) else {
            return XCTFail("stone centre does not project")
        }

        guard let visible = renderer.pickBuffer(
            width: Int(viewport.x),
            height: Int(viewport.y),
            camera: camera,
            scene: scene
        ) else {
            return XCTFail("visible ID pass produced no readback")
        }
        XCTAssertEqual(
            visible.objectID(atX: Int(stonePoint.x), y: Int(stonePoint.y)),
            UInt32(stoneIndex + 1)
        )
        XCTAssertTrue(visible.objectIDs.contains(UInt32(stoneIndex + 1)))

        var hiddenScene = scene
        hiddenScene.nodes[stoneIndex].isVisible = false
        guard let hidden = renderer.pickBuffer(
            width: Int(viewport.x),
            height: Int(viewport.y),
            camera: camera,
            scene: hiddenScene
        ) else {
            return XCTFail("hidden ID pass produced no readback")
        }

        // The hidden node must not appear anywhere in the buffer, not merely
        // at the last centre that was sampled.
        XCTAssertFalse(hidden.objectIDs.contains(UInt32(stoneIndex + 1)))
        let resolved = FFPickResolver.resolve(
            buffer: hidden,
            scene: hiddenScene,
            point: stonePoint
        )
        XCTAssertNotEqual(resolved?.nodeID, scene.nodes[stoneIndex].id)

        // Visibility is not allowed to renumber the remaining nodes.
        guard let shankIndex = scene.nodes.firstIndex(where: { $0.name == "Shank" }) else {
            return XCTFail("demo scene has no shank")
        }
        XCTAssertTrue(hidden.objectIDs.contains(UInt32(shankIndex + 1)))
    }

    func testCurvePickingHitsAtFivePointsAndMissesAtSeven() {
        let camera = FFCamera.standard
        let curve = FFPickCurve(
            name: "Centre line",
            points: [Vec3(x: -25, y: 0, z: 0), Vec3(x: 25, y: 0, z: 0)]
        )
        guard let centre = camera.screenPoint(for: .zero, viewport: viewport) else {
            return XCTFail("origin does not project")
        }
        guard let distance = FFCurvePicker.screenDistance(
            from: Vec2(x: centre.x, y: centre.y + 5),
            to: curve,
            camera: camera,
            viewport: viewport
        ) else {
            return XCTFail("curve produced no screen distance")
        }
        XCTAssertEqual(distance, 5, accuracy: 0.5)

        XCTAssertNotNil(FFCurvePicker.pick(
            curves: [curve],
            at: Vec2(x: centre.x, y: centre.y + 5),
            camera: camera,
            viewport: viewport
        ))
        XCTAssertNil(FFCurvePicker.pick(
            curves: [curve],
            at: Vec2(x: centre.x, y: centre.y + 7),
            camera: camera,
            viewport: viewport
        ))
    }

    func testFiltersRejectTheFrontObjectWithoutFallingThrough() throws {
        let renderer = try makeRenderer()
        let scene = FFViewportScene.jewelleryDemo
        guard let bounds = scene.bounds else { return XCTFail("demo scene has no bounds") }
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.2)
        guard let stoneIndex = scene.nodes.firstIndex(where: { $0.name == "Stone" }) else {
            return XCTFail("demo scene has no stone")
        }
        let stoneCentre = Vec3(
            x: scene.nodes[stoneIndex].transform.m03,
            y: scene.nodes[stoneIndex].transform.m13,
            z: scene.nodes[stoneIndex].transform.m23
        )
        guard let point = camera.screenPoint(for: stoneCentre, viewport: viewport) else {
            return XCTFail("stone centre does not project")
        }

        XCTAssertNil(renderer.pick(
            at: point,
            width: Int(viewport.x),
            height: Int(viewport.y),
            camera: camera,
            scene: scene,
            filter: .solid
        ), "a solid-only filter must reject the stone")

        let stone = renderer.pick(
            at: point,
            width: Int(viewport.x),
            height: Int(viewport.y),
            camera: camera,
            scene: scene,
            filter: .stone
        )
        XCTAssertEqual(stone?.nodeID, scene.nodes[stoneIndex].id)
        XCTAssertEqual(stone?.kind, FFPickKind.stone)
    }

    func testHoverCannotStealTheObjectBeingDragged() {
        let first = FFPickResult(
            nodeID: UUID(),
            name: "Band",
            kind: .solid,
            pixelX: 10,
            pixelY: 10
        )
        let second = FFPickResult(
            nodeID: UUID(),
            name: "Stone",
            kind: .stone,
            pixelX: 40,
            pixelY: 40
        )

        var interaction = FFPickInteraction()
        XCTAssertEqual(interaction.phase, .idle)

        interaction.hover(first)
        XCTAssertEqual(interaction.phase, .hovering(first))
        XCTAssertEqual(interaction.picked, first)

        XCTAssertTrue(interaction.beginDrag(first))
        interaction.hover(second)
        XCTAssertEqual(interaction.phase, .dragging(first))
        XCTAssertEqual(interaction.picked, first)

        interaction.endDrag()
        XCTAssertEqual(interaction.phase, .idle)
        XCTAssertNil(interaction.picked)

        XCTAssertFalse(interaction.beginDrag(nil))
        XCTAssertEqual(interaction.phase, .idle)
    }

    private func expectedNode(
        at point: Vec2,
        scene: FFViewportScene,
        camera: FFCamera
    ) -> Int? {
        guard let ray = camera.ray(at: point, viewport: viewport) else { return nil }
        var best: (index: Int, distance: Double)?

        for (index, node) in scene.nodes.enumerated() where node.isVisible {
            guard let inverse = node.transform.inverse() else { continue }
            let origin = inverse * Vec4(x: ray.origin.x, y: ray.origin.y, z: ray.origin.z, w: 1)
            let direction = inverse * Vec4(x: ray.direction.x, y: ray.direction.y, z: ray.direction.z, w: 0)
            guard abs(origin.w) > FFMath.eps else { continue }

            let localOrigin = Vec3(
                x: origin.x / origin.w,
                y: origin.y / origin.w,
                z: origin.z / origin.w
            )
            let localDirection = Vec3(x: direction.x, y: direction.y, z: direction.z)
            guard let localRay = Ray(origin: localOrigin, direction: localDirection) else {
                continue
            }

            var triangles: [MeshTriangle] = []
            triangles.reserveCapacity(node.mesh.indices.count / 3)
            for start in stride(from: 0, to: node.mesh.indices.count, by: 3) {
                triangles.append(MeshTriangle(
                    Int(node.mesh.indices[start]),
                    Int(node.mesh.indices[start + 1]),
                    Int(node.mesh.indices[start + 2])
                ))
            }
            guard let mesh = IndexedMesh(
                positions: node.mesh.positions,
                triangles: triangles
            ), let hit = mesh.raycast(localRay) else { continue }

            // The demo transforms are rigid, so the local distance is the
            // world distance and is comparable across nodes.
            if let current = best {
                if hit.distance < current.distance { best = (index, hit.distance) }
            } else {
                best = (index, hit.distance)
            }
        }
        return best?.index
    }

    private func makeRenderer() throws -> FFMetalViewportRenderer {
        guard let renderer = FFMetalViewportRenderer() else {
            throw XCTSkip("Metal device unavailable on this simulator")
        }
        return renderer
    }
}
