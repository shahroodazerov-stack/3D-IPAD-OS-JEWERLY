import CryptoKit
import Foundation

/// Version zero of the FacetForge document model.
///
/// The model is deliberately plain data: a tree of nodes, each with a local
/// transform, optional geometry and an optional material reference. Geometry is
/// stored as a serialisable payload (control points, triangles) rather than as
/// the kernel types, so a document never depends on a particular in-memory
/// representation and an unsupported payload can be rejected on load instead of
/// crashing the app.
enum FFDocumentError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case corruptPayload(String)
}

// MARK: - Primitive payloads

/// A serialisable two-dimensional point. Kept separate from `Vec2` so the file
/// format is stable even if the kernel type changes.
struct FFPoint2: Codable, Equatable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ point: Vec2) {
        self.init(x: point.x, y: point.y)
    }

    var vector: Vec2 { Vec2(x: x, y: y) }
}

struct FFPoint3: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(_ point: Vec3) {
        self.init(x: point.x, y: point.y, z: point.z)
    }

    var vector: Vec3 { Vec3(x: x, y: y, z: z) }
}

/// Linear-space colour with premultiplied-free alpha, matching the renderer's
/// sRGB pipeline.
struct FFRGBA: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let gold = FFRGBA(red: 0.83, green: 0.68, blue: 0.33, alpha: 1)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Translation in millimetres, Euler rotation in radians (X then Y then Z) and
/// a per-axis scale. Composing as T * Rz * Ry * Rx * S keeps the matrix
/// deterministic and easy to mirror in the renderer.
struct FFTransform: Codable, Equatable, Sendable {
    var translation: FFPoint3
    var rotation: FFPoint3
    var scale: FFPoint3

    static let identity = FFTransform(
        translation: FFPoint3(x: 0, y: 0, z: 0),
        rotation: FFPoint3(x: 0, y: 0, z: 0),
        scale: FFPoint3(x: 1, y: 1, z: 1)
    )

    init(translation: FFPoint3, rotation: FFPoint3, scale: FFPoint3) {
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
    }

    var matrix: Mat4 {
        Mat4.translation(translation.vector)
            * Mat4.rotationZ(rotation.z)
            * Mat4.rotationY(rotation.y)
            * Mat4.rotationX(rotation.x)
            * Mat4.scale(x: scale.x, y: scale.y, z: scale.z)
    }
}

// MARK: - Geometry payloads

enum FFCurveKind: String, Codable, Sendable {
    case bezier
    case nurbs
}

/// One curve segment in file form. A Bézier segment carries four control
/// points and no weights or knots; a NURBS segment carries its degree, weights
/// and normalised knot vector.
struct FFCurveSegment: Codable, Equatable, Sendable {
    var kind: FFCurveKind
    var controlPoints: [FFPoint2]
    var weights: [Double]
    var degree: Int
    var knots: [Double]

    init(
        kind: FFCurveKind,
        controlPoints: [FFPoint2],
        weights: [Double] = [],
        degree: Int = 1,
        knots: [Double] = []
    ) {
        self.kind = kind
        self.controlPoints = controlPoints
        self.weights = weights
        self.degree = degree
        self.knots = knots
    }

    init(_ curve: Curve2D) {
        switch curve {
        case .bezier(let bezier):
            self.init(kind: .bezier, controlPoints: bezier.controlPoints.map(FFPoint2.init))
        case .nurbs(let nurbs):
            self.init(
                kind: .nurbs,
                controlPoints: nurbs.controlPoints.map(FFPoint2.init),
                weights: nurbs.weights,
                degree: nurbs.degree,
                knots: nurbs.knots
            )
        }
    }

    /// Rebuilds the kernel curve, returning nil when the payload is invalid.
    /// This is the validation seam: a hand-edited or truncated file fails here
    /// instead of producing a curve that silently ignores data.
    var curve: Curve2D? {
        let points = controlPoints.map(\.vector)
        switch kind {
        case .bezier:
            guard weights.isEmpty, knots.isEmpty, points.count >= 2 else { return nil }
            guard let bezier = Bezier2D(points) else { return nil }
            return .bezier(bezier)
        case .nurbs:
            guard let nurbs = NURBSCurve2D(
                degree: degree,
                controlPoints: points,
                weights: weights.isEmpty ? nil : weights,
                knots: knots.isEmpty ? nil : knots
            ) else { return nil }
            return .nurbs(nurbs)
        }
    }
}

/// A connected path of curve segments. `isClosed` is intent, not geometry; the
/// kernel still reports whether the ends meet.
struct FFCurvePayload: Codable, Equatable, Sendable {
    var segments: [FFCurveSegment]
    var isClosed: Bool

    init(segments: [FFCurveSegment], isClosed: Bool = false) {
        self.segments = segments
        self.isClosed = isClosed
    }

    init(_ path: CurvePath2D) {
        self.init(segments: path.curves.map(FFCurveSegment.init), isClosed: path.isClosed())
    }

    func path(tolerance: Double = 1e-7) -> CurvePath2D? {
        let curves = segments.compactMap(\.curve)
        guard curves.count == segments.count, !curves.isEmpty else { return nil }
        return CurvePath2D.joining(curves, tolerance: tolerance)
    }
}

struct FFTriangleIndex: Codable, Equatable, Sendable {
    var a: Int
    var b: Int
    var c: Int

    init(a: Int, b: Int, c: Int) {
        self.a = a
        self.b = b
        self.c = c
    }

    init(_ triangle: MeshTriangle) {
        self.init(a: triangle.a, b: triangle.b, c: triangle.c)
    }

    var triangle: MeshTriangle { MeshTriangle(a, b, c) }
}

/// Indexed triangle mesh in file form. The kernel validates indices on rebuild,
/// so out-of-range or degenerate triangles are rejected rather than loaded.
struct FFMeshPayload: Codable, Equatable, Sendable {
    var positions: [FFPoint3]
    var triangles: [FFTriangleIndex]

    init(positions: [FFPoint3], triangles: [FFTriangleIndex]) {
        self.positions = positions
        self.triangles = triangles
    }

    init(_ mesh: IndexedMesh) {
        self.init(
            positions: mesh.positions.map(FFPoint3.init),
            triangles: mesh.triangles.map(FFTriangleIndex.init)
        )
    }

    var mesh: IndexedMesh? {
        IndexedMesh(
            positions: positions.map(\.vector),
            triangles: triangles.map(\.triangle)
        )
    }
}

enum FFNodeGeometry: Codable, Equatable, Sendable {
    case curve(FFCurvePayload)
    case mesh(FFMeshPayload)

    var curve: FFCurvePayload? {
        guard case .curve(let payload) = self else { return nil }
        return payload
    }

    var mesh: FFMeshPayload? {
        guard case .mesh(let payload) = self else { return nil }
        return payload
    }
}

// MARK: - Scene tree

struct FFMaterial: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var baseColor: FFRGBA
    var metallic: Double
    var roughness: Double

    init(
        id: UUID = UUID(),
        name: String,
        baseColor: FFRGBA = .gold,
        metallic: Double = 1,
        roughness: Double = 0.25
    ) {
        self.id = id
        self.name = name
        self.baseColor = baseColor
        self.metallic = FFMath.clamp(metallic, to: 0...1)
        self.roughness = FFMath.clamp(roughness, to: 0...1)
    }
}

struct FFNode: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var transform: FFTransform
    var isVisible: Bool
    var geometry: FFNodeGeometry?
    var materialID: UUID?
    var children: [FFNode]

    init(
        id: UUID = UUID(),
        name: String,
        transform: FFTransform = .identity,
        isVisible: Bool = true,
        geometry: FFNodeGeometry? = nil,
        materialID: UUID? = nil,
        children: [FFNode] = []
    ) {
        self.id = id
        self.name = name
        self.transform = transform
        self.isVisible = isVisible
        self.geometry = geometry
        self.materialID = materialID
        self.children = children
    }

    var nodeCount: Int {
        1 + children.reduce(0) { $0 + $1.nodeCount }
    }

    func node(withID target: UUID) -> FFNode? {
        if id == target { return self }
        for child in children {
            if let match = child.node(withID: target) { return match }
        }
        return nil
    }

    /// Returns a copy with the matching node replaced, or nil when the subtree
    /// does not contain it. Used by the document's node editing helpers.
    func replacingNode(withID target: UUID, with replacement: (inout FFNode) -> Void) -> FFNode? {
        if id == target {
            var copy = self
            replacement(&copy)
            return copy
        }
        for index in children.indices {
            if let updated = children[index].replacingNode(withID: target, with: replacement) {
                var copy = self
                copy.children[index] = updated
                return copy
            }
        }
        return nil
    }
}

struct FFDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case name
        case displayUnit
        case materials
        case rootNodes
    }

    var schemaVersion: Int
    var name: String
    var displayUnit: FFLengthUnit
    var materials: [FFMaterial]
    var rootNodes: [FFNode]

    init(
        name: String = "Untitled",
        displayUnit: FFLengthUnit = .millimetres,
        materials: [FFMaterial] = [],
        rootNodes: [FFNode] = []
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.name = name
        self.displayUnit = displayUnit
        self.materials = materials
        self.rootNodes = rootNodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version <= Self.currentSchemaVersion else {
            throw FFDocumentError.unsupportedSchemaVersion(version)
        }
        self.schemaVersion = version
        self.name = try container.decode(String.self, forKey: .name)
        self.displayUnit = try container.decodeIfPresent(FFLengthUnit.self, forKey: .displayUnit) ?? .millimetres
        self.materials = try container.decodeIfPresent([FFMaterial].self, forKey: .materials) ?? []
        self.rootNodes = try container.decodeIfPresent([FFNode].self, forKey: .rootNodes) ?? []
    }

    var nodeCount: Int {
        rootNodes.reduce(0) { $0 + $1.nodeCount }
    }

    var curveNodeCount: Int {
        rootNodes.reduce(0) { total, node in
            total + Self.countNodes(in: node) { $0.geometry?.curve != nil }
        }
    }

    var meshNodeCount: Int {
        rootNodes.reduce(0) { total, node in
            total + Self.countNodes(in: node) { $0.geometry?.mesh != nil }
        }
    }

    func node(withID target: UUID) -> FFNode? {
        for root in rootNodes {
            if let match = root.node(withID: target) { return match }
        }
        return nil
    }

    func material(withID target: UUID) -> FFMaterial? {
        materials.first { $0.id == target }
    }

    /// Mutates the node with `target`, returning false when it is absent. The
    /// session's commands use this so an edit never silently does nothing.
    @discardableResult
    mutating func updateNode(withID target: UUID, _ edit: (inout FFNode) -> Void) -> Bool {
        for index in rootNodes.indices {
            if let updated = rootNodes[index].replacingNode(withID: target, with: edit) {
                rootNodes[index] = updated
                return true
            }
        }
        return false
    }

    /// Canonical JSON for hashing and for the save path. Sorted keys make the
    /// output independent of dictionary order and therefore hash-stable.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> FFDocument {
        try JSONDecoder().decode(FFDocument.self, from: data)
    }

    /// SHA-256 of the canonical encoding. Used by the undo/redo tests to prove
    /// that a round trip restores the exact document, not merely an equal one.
    var stateHash: String {
        guard let data = try? encoded() else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func countNodes(in node: FFNode, where predicate: (FFNode) -> Bool) -> Int {
        let own = predicate(node) ? 1 : 0
        return own + node.children.reduce(0) { $0 + countNodes(in: $1, where: predicate) }
    }
}
