import Foundation

/// Generators for the first real scene the viewport draws. They build kernel
/// meshes, so the renderer is fed the same watertight, consistently wound
/// surface the modelling kernel works with.
enum FFMeshFactory {
    /// A closed torus around the Y axis. Outward winding gives a positive
    /// signed volume, which the tests assert so a flipped surface cannot ship.
    static func torus(
        majorRadius: Double,
        minorRadius: Double,
        majorSegments: Int,
        minorSegments: Int
    ) -> IndexedMesh? {
        guard majorRadius > 0,
              minorRadius > 0,
              minorRadius < majorRadius,
              majorSegments >= 3,
              minorSegments >= 3,
              majorSegments * minorSegments <= 65_536
        else { return nil }

        var positions: [Vec3] = []
        positions.reserveCapacity(majorSegments * minorSegments)
        for major in 0..<majorSegments {
            let theta = 2 * Double.pi * Double(major) / Double(majorSegments)
            for minor in 0..<minorSegments {
                let phi = 2 * Double.pi * Double(minor) / Double(minorSegments)
                let radius = majorRadius + minorRadius * cos(phi)
                positions.append(Vec3(
                    x: radius * cos(theta),
                    y: minorRadius * sin(phi),
                    z: radius * sin(theta)
                ))
            }
        }

        var triangles: [MeshTriangle] = []
        triangles.reserveCapacity(majorSegments * minorSegments * 2)
        for major in 0..<majorSegments {
            let nextMajor = (major + 1) % majorSegments
            for minor in 0..<minorSegments {
                let nextMinor = (minor + 1) % minorSegments
                let a = major * minorSegments + minor
                let b = nextMajor * minorSegments + minor
                let c = nextMajor * minorSegments + nextMinor
                let d = major * minorSegments + nextMinor
                triangles.append(MeshTriangle(a, c, b))
                triangles.append(MeshTriangle(a, d, c))
            }
        }
        return IndexedMesh(positions: positions, triangles: triangles)
    }

    /// Eight flat facets around a point, the smallest faceted gem that still
    /// exercises per-face normals.
    static func octahedron(radius: Double) -> IndexedMesh? {
        guard radius > 0 else { return nil }
        let positions = [
            Vec3(x: radius, y: 0, z: 0),
            Vec3(x: -radius, y: 0, z: 0),
            Vec3(x: 0, y: radius, z: 0),
            Vec3(x: 0, y: -radius, z: 0),
            Vec3(x: 0, y: 0, z: radius),
            Vec3(x: 0, y: 0, z: -radius)
        ]
        let faces = [
            (0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4),
            (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)
        ]
        return IndexedMesh(
            positions: positions,
            triangles: faces.map { MeshTriangle($0.0, $0.1, $0.2) }
        )
    }
}

extension FFViewportScene {
    /// The bench sample shown until a document is loaded: a 60 mm shank
    /// standing upright with a faceted stone selected at the top.
    static let jewelleryDemo: FFViewportScene = {
        var nodes: [FFRenderNode] = []

        if let band = FFMeshFactory.torus(
            majorRadius: 30,
            minorRadius: 4.5,
            majorSegments: 120,
            minorSegments: 28
        ), let mesh = FFRenderMesh(mesh: band) {
            nodes.append(FFRenderNode(
                name: "Shank",
                mesh: mesh,
                transform: Mat4.rotationX(.pi / 2),
                material: .gold
            ))
        }

        if let stone = FFMeshFactory.octahedron(radius: 6), let mesh = FFRenderMesh(mesh: stone) {
            nodes.append(FFRenderNode(
                name: "Stone",
                mesh: mesh,
                transform: Mat4.translation(Vec3(x: 0, y: 40, z: 0)),
                material: .gem,
                isSelected: true
            ))
        }

        return FFViewportScene(nodes: nodes)
    }()
}
