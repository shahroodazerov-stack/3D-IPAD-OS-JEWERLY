import XCTest
@testable import FacetForge

private struct MeshRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func double(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }
}

private func makeMesh(_ positions: [Vec3], _ faces: [(Int, Int, Int)]) -> IndexedMesh {
    let triangles = faces.map { MeshTriangle($0.0, $0.1, $0.2) }
    guard let mesh = IndexedMesh(positions: positions, triangles: triangles) else {
        fatalError("fixture is not a valid indexed mesh")
    }
    return mesh
}

private func cubeFaces() -> [(Int, Int, Int)] {
    [
        (0, 2, 1), (0, 3, 2),
        (4, 5, 6), (4, 6, 7),
        (0, 1, 5), (0, 5, 4),
        (3, 7, 6), (3, 6, 2),
        (0, 4, 7), (0, 7, 3),
        (1, 2, 6), (1, 6, 5),
    ]
}

private func cubePositions() -> [Vec3] {
    [
        Vec3(x: 0, y: 0, z: 0),
        Vec3(x: 1, y: 0, z: 0),
        Vec3(x: 1, y: 1, z: 0),
        Vec3(x: 0, y: 1, z: 0),
        Vec3(x: 0, y: 0, z: 1),
        Vec3(x: 1, y: 0, z: 1),
        Vec3(x: 1, y: 1, z: 1),
        Vec3(x: 0, y: 1, z: 1),
    ]
}

private func cube(flippedFace: Int? = nil) -> IndexedMesh {
    var faces = cubeFaces()
    if let flippedFace {
        let face = faces[flippedFace]
        faces[flippedFace] = (face.0, face.2, face.1)
    }
    return makeMesh(cubePositions(), faces)
}

private func invertedCube() -> IndexedMesh {
    makeMesh(cubePositions(), cubeFaces().map { ($0.0, $0.2, $0.1) })
}

private func transformedCube() -> IndexedMesh {
    let positions = cubePositions().map { position in
        Vec3(
            x: 2.5 * position.x - 4,
            y: 1.5 * position.y + 2,
            z: 0.75 * position.z
        )
    }
    return makeMesh(positions, cubeFaces())
}

private func tetraPositions() -> [Vec3] {
    [
        Vec3(x: 0, y: 0, z: 0),
        Vec3(x: 1, y: 0, z: 0),
        Vec3(x: 0, y: 1, z: 0),
        Vec3(x: 0, y: 0, z: 1),
    ]
}

private func tetraFaces() -> [(Int, Int, Int)] {
    [(0, 2, 1), (0, 1, 3), (0, 3, 2), (1, 2, 3)]
}

private func tetra(flippedFace: Int? = nil) -> IndexedMesh {
    var faces = tetraFaces()
    if let flippedFace {
        let face = faces[flippedFace]
        faces[flippedFace] = (face.0, face.2, face.1)
    }
    return makeMesh(tetraPositions(), faces)
}

private func octahedron() -> IndexedMesh {
    let positions = [
        Vec3(x: 1, y: 0, z: 0),
        Vec3(x: -1, y: 0, z: 0),
        Vec3(x: 0, y: 1, z: 0),
        Vec3(x: 0, y: -1, z: 0),
        Vec3(x: 0, y: 0, z: 1),
        Vec3(x: 0, y: 0, z: -1),
    ]
    let faces: [(Int, Int, Int)] = [
        (0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2),
        (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5),
    ]
    return makeMesh(positions, faces)
}

private func grid(segments: Int = 2) -> IndexedMesh {
    var positions: [Vec3] = []
    for row in 0...segments {
        for column in 0...segments {
            positions.append(Vec3(
                x: Double(column) / Double(segments),
                y: Double(row) / Double(segments),
                z: 0
            ))
        }
    }

    var faces: [(Int, Int, Int)] = []
    let stride = segments + 1
    for row in 0..<segments {
        for column in 0..<segments {
            let a = row * stride + column
            let b = a + 1
            let c = a + stride
            let d = c + 1
            faces.append((a, b, d))
            faces.append((a, d, c))
        }
    }
    return makeMesh(positions, faces)
}

private func pentagonFan() -> IndexedMesh {
    var positions = [Vec3(x: 0, y: 0, z: 0)]
    for index in 0..<5 {
        let angle = Double(index) * 2 * .pi / 5
        positions.append(Vec3(x: cos(angle), y: sin(angle), z: 0))
    }
    var faces: [(Int, Int, Int)] = []
    for index in 0..<5 {
        faces.append((0, index + 1, (index + 1) % 5 + 1))
    }
    return makeMesh(positions, faces)
}

private func cylinder(includeCaps: Bool, segments: Int = 8) -> IndexedMesh {
    var positions: [Vec3] = []
    for z in [0.0, 1.0] {
        for index in 0..<segments {
            let angle = Double(index) * 2 * .pi / Double(segments)
            positions.append(Vec3(x: cos(angle), y: sin(angle), z: z))
        }
    }

    var faces: [(Int, Int, Int)] = []
    for index in 0..<segments {
        let next = (index + 1) % segments
        let a = index
        let b = next
        let c = segments + index
        let d = segments + next
        faces.append((a, b, d))
        faces.append((a, d, c))
    }

    if includeCaps {
        let bottomCenter = positions.count
        positions.append(Vec3(x: 0, y: 0, z: 0))
        let topCenter = positions.count
        positions.append(Vec3(x: 0, y: 0, z: 1))
        for index in 0..<segments {
            let next = (index + 1) % segments
            faces.append((bottomCenter, next, index))
            faces.append((topCenter, segments + index, segments + next))
        }
    }
    return makeMesh(positions, faces)
}

private func twoDisjointTriangles() -> IndexedMesh {
    makeMesh(
        [
            Vec3(x: 0, y: 0, z: 0),
            Vec3(x: 1, y: 0, z: 0),
            Vec3(x: 0, y: 1, z: 0),
            Vec3(x: 4, y: 0, z: 0),
            Vec3(x: 5, y: 0, z: 0),
            Vec3(x: 4, y: 1, z: 0),
        ],
        [(0, 1, 2), (3, 4, 5)]
    )
}

private func bowTie() -> IndexedMesh {
    makeMesh(
        [
            Vec3(x: 0, y: 0, z: 0),
            Vec3(x: 1, y: 0, z: 0),
            Vec3(x: 0, y: 1, z: 0),
            Vec3(x: -1, y: 0, z: 0),
            Vec3(x: 0, y: -1, z: 0),
        ],
        [(0, 1, 2), (0, 3, 4)]
    )
}

private func threeTrianglesOnOneEdge() -> IndexedMesh {
    makeMesh(
        [
            Vec3(x: 0, y: 0, z: 0),
            Vec3(x: 1, y: 0, z: 0),
            Vec3(x: 0, y: 1, z: 0),
            Vec3(x: 0, y: -1, z: 0),
            Vec3(x: 1, y: 1, z: 0),
        ],
        [(0, 1, 2), (0, 1, 3), (0, 1, 4)]
    )
}

private func duplicateTriangle() -> IndexedMesh {
    let positions = [
        Vec3(x: 0, y: 0, z: 0),
        Vec3(x: 1, y: 0, z: 0),
        Vec3(x: 0, y: 1, z: 0),
    ]
    return makeMesh(positions, [(0, 1, 2), (0, 1, 2)])
}

private func cubeWithFin() -> IndexedMesh {
    var positions = cubePositions()
    positions.append(Vec3(x: 0.5, y: -0.5, z: 0.5))
    var faces = cubeFaces()
    faces.append((0, 1, positions.count - 1))
    return makeMesh(positions, faces)
}

private func twoTetrahedraSharingAFace() -> IndexedMesh {
    var positions = tetraPositions()
    positions.append(Vec3(x: 0, y: 0, z: -1))
    let faces = tetraFaces() + [
        (0, 1, 2),
        (0, 4, 1),
        (1, 4, 2),
        (2, 4, 0),
    ]
    return makeMesh(positions, faces)
}

private func twoTetrahedraSharingAVertex() -> IndexedMesh {
    let positions = tetraPositions() + [
        Vec3(x: 2, y: 0, z: 0),
        Vec3(x: 2, y: 1, z: 0),
        Vec3(x: 2, y: 0, z: 1),
    ]
    let faces = tetraFaces() + [
        (0, 4, 6),
        (0, 6, 5),
        (0, 5, 4),
        (4, 5, 6),
    ]
    return makeMesh(positions, faces)
}

private struct MeshFixture {
    let name: String
    let mesh: IndexedMesh
    let isManifold: Bool
    let isWatertight: Bool
    let isConsistentlyOriented: Bool
}

private func meshFixtures() -> [MeshFixture] {
    [
        MeshFixture(name: "single triangle", mesh: makeMesh(
            [Vec3(x: 0, y: 0, z: 0), Vec3(x: 1, y: 0, z: 0), Vec3(x: 0, y: 1, z: 0)],
            [(0, 1, 2)]
        ), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "quad", mesh: makeMesh(
            [Vec3(x: 0, y: 0, z: 0), Vec3(x: 1, y: 0, z: 0), Vec3(x: 0, y: 1, z: 0), Vec3(x: 1, y: 1, z: 0)],
            [(0, 1, 3), (0, 3, 2)]
        ), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "pentagon fan", mesh: pentagonFan(), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "two by two grid", mesh: grid(), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "tetrahedron", mesh: tetra(), isManifold: true, isWatertight: true, isConsistentlyOriented: true),
        MeshFixture(name: "cube", mesh: cube(), isManifold: true, isWatertight: true, isConsistentlyOriented: true),
        MeshFixture(name: "octahedron", mesh: octahedron(), isManifold: true, isWatertight: true, isConsistentlyOriented: true),
        MeshFixture(name: "open box", mesh: makeMesh(cubePositions(), cubeFaces().enumerated().compactMap { index, face in
            index == 2 || index == 3 ? nil : face
        }), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "open tetrahedron", mesh: makeMesh(tetraPositions(), tetraFaces().enumerated().compactMap { index, face in
            index == 3 ? nil : face
        }), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "open cylinder", mesh: cylinder(includeCaps: false), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "closed cylinder", mesh: cylinder(includeCaps: true), isManifold: true, isWatertight: true, isConsistentlyOriented: true),
        MeshFixture(name: "two disjoint triangles", mesh: twoDisjointTriangles(), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "two triangles sharing one vertex", mesh: bowTie(), isManifold: false, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "three triangles on one edge", mesh: threeTrianglesOnOneEdge(), isManifold: false, isWatertight: false, isConsistentlyOriented: false),
        MeshFixture(name: "duplicate same-winding triangle", mesh: duplicateTriangle(), isManifold: false, isWatertight: false, isConsistentlyOriented: false),
        MeshFixture(name: "cube with one flipped triangle", mesh: cube(flippedFace: 0), isManifold: false, isWatertight: false, isConsistentlyOriented: false),
        MeshFixture(name: "tetrahedron with one flipped face", mesh: tetra(flippedFace: 0), isManifold: false, isWatertight: false, isConsistentlyOriented: false),
        MeshFixture(name: "cube with a duplicate triangle", mesh: makeMesh(cubePositions(), cubeFaces() + [cubeFaces()[0]]), isManifold: false, isWatertight: false, isConsistentlyOriented: false),
        MeshFixture(name: "cube with an edge fin", mesh: cubeWithFin(), isManifold: false, isWatertight: false, isConsistentlyOriented: false),
        MeshFixture(name: "cube missing top", mesh: makeMesh(cubePositions(), cubeFaces().enumerated().compactMap { index, face in
            index == 2 || index == 3 ? nil : face
        }), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "cube missing front", mesh: makeMesh(cubePositions(), cubeFaces().enumerated().compactMap { index, face in
            index == 4 || index == 5 ? nil : face
        }), isManifold: true, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "two tetrahedra sharing a face", mesh: twoTetrahedraSharingAFace(), isManifold: false, isWatertight: false, isConsistentlyOriented: false),
        MeshFixture(name: "two tetrahedra sharing a vertex", mesh: twoTetrahedraSharingAVertex(), isManifold: false, isWatertight: false, isConsistentlyOriented: true),
        MeshFixture(name: "inverted cube", mesh: invertedCube(), isManifold: true, isWatertight: true, isConsistentlyOriented: true),
        MeshFixture(name: "transformed cube", mesh: transformedCube(), isManifold: true, isWatertight: true, isConsistentlyOriented: true),
    ]
}

final class MeshKernelTests: XCTestCase {
    func testTwentyFiveFixturesAreClassifiedCorrectly() {
        let fixtures = meshFixtures()
        XCTAssertEqual(fixtures.count, 25)

        var failures: [String] = []
        for fixture in fixtures {
            let actual = fixture.mesh.classification
            if actual.isManifold != fixture.isManifold {
                failures.append("\(fixture.name): manifold \(actual.isManifold), expected \(fixture.isManifold)")
            }
            if actual.isWatertight != fixture.isWatertight {
                failures.append("\(fixture.name): watertight \(actual.isWatertight), expected \(fixture.isWatertight)")
            }
            if actual.isConsistentlyOriented != fixture.isConsistentlyOriented {
                failures.append("\(fixture.name): oriented \(actual.isConsistentlyOriented), expected \(fixture.isConsistentlyOriented)")
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testBoundaryAndNonManifoldCountsOnTheCoreCases() {
        XCTAssertEqual(
            meshFixtures()[0].mesh.classification.boundaryEdgeCount,
            3
        )
        XCTAssertEqual(cube().classification.boundaryEdgeCount, 0)
        XCTAssertEqual(bowTie().classification.nonManifoldVertexCount, 1)
        XCTAssertEqual(threeTrianglesOnOneEdge().classification.nonManifoldEdgeCount, 1)
        XCTAssertEqual(duplicateTriangle().classification.nonManifoldVertexCount, 3)
    }

    func testWeldingMergesVerticesAndDropsCollapsedTriangles() {
        let mesh = makeMesh(
            [
                Vec3(x: 0, y: 0, z: 0),
                Vec3(x: 1, y: 0, z: 0),
                Vec3(x: 0, y: 1, z: 0),
                Vec3(x: 1, y: 0, z: 0),
            ],
            [(0, 1, 2), (0, 1, 3)]
        )
        let welded = mesh.welded(tolerance: 1e-9)
        XCTAssertEqual(welded.positions.count, 3)
        XCTAssertEqual(welded.triangles.count, 1)
        XCTAssertEqual(welded.triangles[0], MeshTriangle(0, 1, 2))
    }

    func testCubeNormalsBoundsAndSignedVolume() {
        let cube = cube()
        XCTAssertEqual(cube.triangleCount, 12)
        XCTAssertEqual(cube.bounds?.minimum ?? .zero, Vec3(x: 0, y: 0, z: 0))
        XCTAssertEqual(cube.bounds?.maximum ?? .zero, Vec3(x: 1, y: 1, z: 1))
        XCTAssertEqual(cube.signedVolume(), 1, accuracy: 1e-12)

        let normals = cube.vertexNormals()
        XCTAssertEqual(normals.count, cube.positions.count)
        for normal in normals {
            XCTAssertEqual(normal.length, 1, accuracy: 1e-12)
        }
        for index in cube.triangles.indices {
            XCTAssertEqual(cube.triangleArea(index), 0.5, accuracy: 1e-12)
            XCTAssertEqual(cube.faceNormal(index)?.length ?? 0, 1, accuracy: 1e-12)
        }
    }

    func testBVHMatchesBruteForceAcrossTenThousandRays() {
        let mesh = cylinder(includeCaps: true)
        let bvh = MeshBVH(mesh: mesh)
        XCTAssertGreaterThan(bvh.nodes.count, 1)

        var random = MeshRandom(seed: 7)
        var hitCount = 0
        var checkedCount = 0

        while checkedCount < 10_000 {
            let origin = Vec3(
                x: random.double(-1.5, 1.5),
                y: random.double(-1.5, 1.5),
                z: random.double(-1.5, 1.5)
            )
            let direction = Vec3(
                x: random.double(-1, 1),
                y: random.double(-1, 1),
                z: random.double(-1, 1)
            )
            guard let ray = Ray(origin: origin, direction: direction) else { continue }
            checkedCount += 1

            let expected = mesh.raycast(ray)
            let actual = bvh.raycast(ray)
            switch (expected, actual) {
            case (nil, nil):
                break
            case let (expected?, actual?):
                hitCount += 1
                XCTAssertEqual(actual.triangleIndex, expected.triangleIndex, "ray \(checkedCount)")
                XCTAssertEqual(actual.distance, expected.distance, accuracy: 1e-9, "ray \(checkedCount)")
                XCTAssertLessThan(actual.point.distance(to: expected.point), 1e-9, "ray \(checkedCount)")
                XCTAssertLessThan(actual.barycentric.lengthSquared, 2, "ray \(checkedCount)")
            default:
                XCTFail("BVH and brute force disagree on ray \(checkedCount): \(String(describing: expected)) vs \(String(describing: actual))")
            }
        }
        XCTAssertGreaterThan(hitCount, 1_000)
    }

    func testEmptyMeshHasNoBoundsOrBVHHits() {
        let mesh = IndexedMesh(positions: [], triangles: [])!
        XCTAssertNil(mesh.bounds)
        let bvh = MeshBVH(mesh: mesh)
        XCTAssertTrue(bvh.nodes.isEmpty)
        XCTAssertNil(bvh.raycast(Ray(origin: Vec3(x: 0, y: 0, z: 0), direction: Vec3(x: 0, y: 0, z: 1))!))
    }
}
