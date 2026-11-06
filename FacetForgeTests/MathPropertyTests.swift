import XCTest
@testable import FacetForge

/// A named, deterministic property check. The catalog is intentionally data
/// driven so the gate can prove a broad set of identities without duplicating
/// the same XCTest boilerplate 120 times.
private struct MathPropertyCase {
    let name: String
    let check: () -> String?
}

private enum MathPropertyCatalog {
    static let cases: [MathPropertyCase] = {
        var result: [MathPropertyCase] = []

        for seed in 0..<11 {
            let value = UInt64(seed)
            result.append(MathPropertyCase(name: "vec2-algebra-\(seed)") {
                checkVec2Algebra(seed: value)
            })
            result.append(MathPropertyCase(name: "vec2-normalize-\(seed)") {
                checkVec2Normalize(seed: value)
            })
            result.append(MathPropertyCase(name: "vec3-cross-\(seed)") {
                checkVec3Cross(seed: value)
            })
            result.append(MathPropertyCase(name: "vec3-normalize-\(seed)") {
                checkVec3Normalize(seed: value)
            })
            result.append(MathPropertyCase(name: "vec4-perspective-\(seed)") {
                checkVec4Perspective(seed: value)
            })
            result.append(MathPropertyCase(name: "mat3-inverse-\(seed)") {
                checkMat3Inverse(seed: value)
            })
            result.append(MathPropertyCase(name: "mat3-determinant-\(seed)") {
                checkMat3Determinant(seed: value)
            })
            result.append(MathPropertyCase(name: "mat4-inverse-\(seed)") {
                checkMat4Inverse(seed: value)
            })
            result.append(MathPropertyCase(name: "mat4-transform-\(seed)") {
                checkMat4Transform(seed: value)
            })
            result.append(MathPropertyCase(name: "quat-rotation-\(seed)") {
                checkQuatRotation(seed: value)
            })
            result.append(MathPropertyCase(name: "plane-geometry-\(seed)") {
                checkPlaneGeometry(seed: value)
            })
            result.append(MathPropertyCase(name: "aabb-ray-\(seed)") {
                checkAABBRay(seed: value)
            })
        }

        return result
    }()
}

private struct FFRandom {
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

    mutating func vec2() -> Vec2 {
        Vec2(x: double(-2, 2), y: double(-2, 2))
    }

    mutating func vec3(_ lower: Double = -2, _ upper: Double = 2) -> Vec3 {
        Vec3(
            x: double(lower, upper),
            y: double(lower, upper),
            z: double(lower, upper)
        )
    }

    mutating func nonzeroVec2() -> Vec2 {
        var value = vec2()
        if value.length < 0.1 {
            value = value + Vec2(x: 1.3, y: 0.7)
        }
        return value
    }

    mutating func nonzeroVec3() -> Vec3 {
        var value = vec3()
        if value.length < 0.1 {
            value = value + Vec3(x: 1.3, y: 0.7, z: 0.4)
        }
        return value
    }
}

private func checkVec2Algebra(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let a = random.vec2()
    let b = random.vec2()
    let c = random.vec2()

    if (a + b).distance(to: b + a) > 1e-12 {
        return "Vec2 addition is not commutative"
    }
    if ((a + b) + c).distance(to: a + (b + c)) > 1e-12 {
        return "Vec2 addition is not associative"
    }
    if abs(a.dot(b) - b.dot(a)) > 1e-12 {
        return "Vec2 dot product is not symmetric"
    }
    if ((a + b) * 2).distance(to: a * 2 + b * 2) > 1e-12 {
        return "Vec2 scalar multiplication does not distribute"
    }
    return nil
}

private func checkVec2Normalize(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let value = random.nonzeroVec2()
    guard let unit = value.normalized() else {
        return "a non-zero Vec2 failed to normalize"
    }
    if abs(unit.length - 1) > 1e-12 {
        return "normalized Vec2 has length \(unit.length)"
    }
    guard let scaled = (value * -7.5).normalized() else {
        return "a scaled non-zero Vec2 failed to normalize"
    }
    if scaled.distance(to: unit) > 1e-12 {
        return "normalization depends on magnitude"
    }
    if Vec2.zero.normalized() != nil {
        return "zero Vec2 normalized instead of being rejected"
    }
    return nil
}

private func checkVec3Cross(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let a = random.nonzeroVec3()
    let b = random.nonzeroVec3()
    let cross = a.cross(b)
    let scale = max(1, a.length * b.length)

    if abs(cross.dot(a)) > 1e-10 * scale {
        return "cross product is not perpendicular to the first vector"
    }
    if abs(cross.dot(b)) > 1e-10 * scale {
        return "cross product is not perpendicular to the second vector"
    }
    let lagrange = cross.lengthSquared
        - (a.lengthSquared * b.lengthSquared - a.dot(b) * a.dot(b))
    if abs(lagrange) > 1e-9 * max(1, a.lengthSquared * b.lengthSquared) {
        return "cross product violates the Lagrange identity"
    }
    return nil
}

private func checkVec3Normalize(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let value = random.nonzeroVec3()
    guard let unit = value.normalized() else {
        return "a non-zero Vec3 failed to normalize"
    }
    if abs(unit.length - 1) > 1e-12 {
        return "normalized Vec3 has length \(unit.length)"
    }
    guard let scaled = (value * -4.25).normalized() else {
        return "a scaled non-zero Vec3 failed to normalize"
    }
    if scaled.distance(to: unit) > 1e-12 {
        return "normalization depends on magnitude"
    }
    if Vec3.zero.normalized() != nil {
        return "zero Vec3 normalized instead of being rejected"
    }
    return nil
}

private func checkVec4Perspective(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let weight = random.double(0.25, 3.0)
    let value = Vec4(
        x: random.double(-4, 4),
        y: random.double(-4, 4),
        z: random.double(-4, 4),
        w: weight
    )
    guard let divided = value.perspectiveDivide() else {
        return "a finite homogeneous point failed to divide"
    }
    let expected = value.xyz * (1 / weight)
    if divided.distance(to: expected) > 1e-12 {
        return "perspective divide used the wrong weight"
    }
    let atInfinity = Vec4(x: value.x, y: value.y, z: value.z, w: 0)
    if atInfinity.perspectiveDivide() != nil {
        return "a point at infinity was given an affine position"
    }
    return nil
}

private func checkMat3Inverse(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let matrix = Mat3.rotationZ(random.double(-3.1, 3.1))
        * Mat3.scale(
            x: random.double(0.5, 2.0),
            y: random.double(0.5, 2.0),
            z: random.double(0.5, 2.0)
        )
    guard let inverse = matrix.inverse() else {
        return "a well-conditioned Mat3 failed to invert"
    }
    let forward = (matrix * inverse).maximumAbsoluteDifference(from: .identity)
    let backward = (inverse * matrix).maximumAbsoluteDifference(from: .identity)
    if forward >= 1e-12 || backward >= 1e-12 {
        return "Mat3 inverse round-trip error \(max(forward, backward)) is not below 1e-12"
    }
    return nil
}

private func checkMat3Determinant(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let matrix = Mat3.rotationZ(random.double(-3.1, 3.1))
        * Mat3.scale(
            x: random.double(0.5, 2.0),
            y: random.double(0.5, 2.0),
            z: random.double(0.5, 2.0)
        )
    let determinant = matrix.determinant
    if abs(matrix.transposed.determinant - determinant) > 1e-12 * max(1, abs(determinant)) {
        return "transpose changed the determinant"
    }
    guard let inverse = matrix.inverse() else {
        return "a non-singular Mat3 failed to invert"
    }
    if abs(inverse.determinant - 1 / determinant) > 1e-12 * max(1, abs(1 / determinant)) {
        return "inverse determinant is not the reciprocal"
    }
    return nil
}

private func checkMat4Inverse(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let matrix = Mat4.translation(random.vec3(-3, 3))
        * Mat4.rotationX(random.double(-3.1, 3.1))
        * Mat4.rotationY(random.double(-3.1, 3.1))
        * Mat4.rotationZ(random.double(-3.1, 3.1))
        * Mat4.scale(
            x: random.double(0.5, 2.0),
            y: random.double(0.5, 2.0),
            z: random.double(0.5, 2.0)
        )
    guard let inverse = matrix.inverse() else {
        return "a well-conditioned Mat4 failed to invert"
    }
    let forward = (matrix * inverse).maximumAbsoluteDifference(from: .identity)
    let backward = (inverse * matrix).maximumAbsoluteDifference(from: .identity)
    if forward >= 1e-12 || backward >= 1e-12 {
        return "Mat4 inverse round-trip error \(max(forward, backward)) is not below 1e-12"
    }
    return nil
}

private func checkMat4Transform(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let point = random.vec3(-4, 4)
    let offset = random.vec3(-2, 2)
    let translation = Mat4.translation(offset)

    if translation.transformedPoint(point).distance(to: point + offset) > 1e-12 {
        return "translation did not move the point by the offset"
    }
    if translation.transformedVector(point).distance(to: point) > 1e-12 {
        return "translation moved a direction vector"
    }

    let transform = Mat4.rotationZ(random.double(-3.1, 3.1))
        * Mat4.scale(
            x: random.double(0.5, 2.0),
            y: random.double(0.5, 2.0),
            z: random.double(0.5, 2.0)
        )
    let transformed = transform.transformedPoint(point)
    guard let inverse = transform.inverse() else {
        return "a well-conditioned affine Mat4 failed to invert"
    }
    if inverse.transformedPoint(transformed).distance(to: point) > 1e-12 {
        return "point transform did not round-trip through the inverse"
    }
    return nil
}

private func checkQuatRotation(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let axis = random.nonzeroVec3()
    let angle = random.double(-3.0, 3.0)
    guard let quaternion = Quat(axis: axis, angle: angle) else {
        return "a non-zero axis failed to build a quaternion"
    }
    if abs(quaternion.length - 1) > 1e-12 {
        return "axis-angle quaternion is not unit length"
    }

    let vector = random.vec3(-2, 2)
    let rotated = quaternion.rotated(vector)
    if abs(rotated.length - vector.length) > 1e-10 {
        return "rotation changed the vector length"
    }
    if (quaternion.toMat3() * vector).distance(to: rotated) > 1e-10 {
        return "quaternion matrix disagrees with quaternion rotation"
    }

    guard let inverse = quaternion.inverse() else {
        return "a unit quaternion failed to invert"
    }
    let identity = quaternion * inverse
    let error = max(
        max(abs(identity.x), abs(identity.y)),
        max(abs(identity.z), abs(identity.w - 1))
    )
    if error >= 1e-12 {
        return "quaternion inverse round-trip error \(error) is not below 1e-12"
    }
    return nil
}

private func checkPlaneGeometry(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let point = random.vec3(-2, 2)
    let normal = random.nonzeroVec3()
    guard let plane = Plane(normal: normal, point: point) else {
        return "a non-zero normal failed to build a plane"
    }
    if abs(plane.normal.length - 1) > 1e-12 {
        return "plane normal is not unit length"
    }

    let query = random.vec3(-2, 2)
    let distance = plane.signedDistance(to: query)
    let projected = plane.project(query)
    if abs(plane.signedDistance(to: projected)) > 1e-10 {
        return "projected point is not on the plane"
    }
    if projected.distance(to: plane.project(projected)) > 1e-10 {
        return "projection is not idempotent"
    }
    let mirrored = plane.mirrored(query)
    if abs(plane.signedDistance(to: mirrored) + distance) > 1e-10 {
        return "mirroring did not negate the signed distance"
    }
    if Plane(normal: .zero, point: point) != nil {
        return "zero normal produced a plane"
    }
    return nil
}

private func checkAABBRay(seed: UInt64) -> String? {
    var random = FFRandom(seed: seed)
    let center = random.vec3(-1, 1)
    let halfSize = Vec3(
        x: random.double(0.25, 2.0),
        y: random.double(0.25, 2.0),
        z: random.double(0.25, 2.0)
    )
    let box = AABB(minimum: center - halfSize, maximum: center + halfSize)
    if !box.contains(center) {
        return "box does not contain its own centre"
    }

    guard let outward = random.nonzeroVec3().normalized() else {
        return "a non-zero direction failed to normalize"
    }
    let start = center + outward * 10
    guard let ray = Ray(origin: start, direction: -outward) else {
        return "a non-zero ray direction was rejected"
    }
    guard let hit = ray.intersection(with: box) else {
        return "ray aimed at the box missed"
    }
    if hit < -1e-9 || hit > 10 + 1e-9 {
        return "ray hit distance \(hit) is outside the expected interval"
    }

    let degenerate = AABB(minimum: center, maximum: center)
    if !degenerate.contains(center) {
        return "degenerate box does not contain its point"
    }
    if !box.intersects(degenerate) {
        return "box does not intersect the degenerate box inside it"
    }
    if !box.union(degenerate).contains(center) {
        return "union does not contain the degenerate box"
    }
    return nil
}

final class MathPropertyTests: XCTestCase {
    func testThePropertyCatalogCoversAtLeast120Cases() {
        XCTAssertGreaterThanOrEqual(MathPropertyCatalog.cases.count, 120)
        XCTAssertEqual(
            Set(MathPropertyCatalog.cases.map { $0.name }).count,
            MathPropertyCatalog.cases.count,
            "property case names must be unique"
        )
    }

    func testEveryMathPropertyHolds() {
        var failures: [String] = []
        for property in MathPropertyCatalog.cases {
            if let failure = property.check() {
                failures.append("\(property.name): \(failure)")
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testPlaneOffsetScalesWithTheNormal() throws {
        let plane = try XCTUnwrap(Plane(normal: Vec3(x: 0, y: 0, z: 2), offset: 8))
        XCTAssertEqual(plane.normal, Vec3(x: 0, y: 0, z: 1))
        XCTAssertEqual(plane.offset, 4)
        XCTAssertEqual(plane.signedDistance(to: Vec3(x: 0, y: 0, z: 4)), 0)
    }

    func testDegenerateNormalsAndDirectionsAreRejected() {
        XCTAssertNil(Vec2.zero.normalized())
        XCTAssertNil(Vec3.zero.normalized())
        XCTAssertNil(Vec4.zero.normalized())
        XCTAssertNil(Plane(normal: .zero, point: Vec3(x: 1, y: 2, z: 3)))
        XCTAssertNil(Quat(axis: .zero, angle: 1))
        XCTAssertNil(Ray(origin: .zero, direction: .zero))
    }

    func testInverseRoundTripsMeetTheAcceptanceTolerance() throws {
        let matrix3 = Mat3.rotationZ(0.73) * Mat3.scale(x: 1.3, y: 0.8, z: 1.7)
        let inverse3 = try XCTUnwrap(matrix3.inverse())
        XCTAssertLessThan(
            (matrix3 * inverse3).maximumAbsoluteDifference(from: .identity),
            1e-12
        )

        let matrix4 = Mat4.translation(Vec3(x: 4, y: -3, z: 2))
            * Mat4.rotationX(0.31)
            * Mat4.rotationY(-0.57)
            * Mat4.rotationZ(0.93)
            * Mat4.scale(x: 1.4, y: 0.9, z: 1.2)
        let inverse4 = try XCTUnwrap(matrix4.inverse())
        XCTAssertLessThan(
            (matrix4 * inverse4).maximumAbsoluteDifference(from: .identity),
            1e-12
        )

        let quaternion = try XCTUnwrap(
            Quat(axis: Vec3(x: 0.3, y: -0.7, z: 0.2), angle: 1.17)
        )
        let inverse = try XCTUnwrap(quaternion.inverse())
        let identity = quaternion * inverse
        let error = max(
            max(abs(identity.x), abs(identity.y)),
            max(abs(identity.z), abs(identity.w - 1))
        )
        XCTAssertLessThan(error, 1e-12)
    }

    func testSingularMatrixInverseIsRejected() {
        let singular = Mat3(
            m00: 1, m01: 2, m02: 3,
            m10: 2, m11: 4, m12: 6,
            m20: 0, m21: 1, m22: 1
        )
        XCTAssertNil(singular.inverse())

        let singular4 = Mat4(
            m00: 1, m01: 2, m02: 3, m03: 0,
            m10: 2, m11: 4, m12: 6, m13: 0,
            m20: 0, m21: 1, m22: 1, m23: 0,
            m30: 0, m31: 0, m32: 0, m33: 1
        )
        XCTAssertNil(singular4.inverse())
    }
}
