import Foundation

/// Shared numeric policy for the geometry stack.
///
/// Values are millimetres in double precision. `eps` is an absolute tolerance
/// for unit-scale comparisons, not a replacement for a scale-aware tolerance
/// in a later kernel algorithm.
enum FFMath {
    /// Absolute tolerance for comparisons on unit-scale geometry.
    static let eps = 1e-9

    static func isApproximatelyEqual(
        _ lhs: Double,
        _ rhs: Double,
        tolerance: Double = FFMath.eps
    ) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

    static func isZero(_ value: Double, tolerance: Double = FFMath.eps) -> Bool {
        abs(value) <= tolerance
    }

    static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}

/// A two-dimensional vector in the sketch plane.
struct Vec2: Equatable, Sendable {
    var x: Double
    var y: Double

    static let zero = Vec2(x: 0, y: 0)

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    var lengthSquared: Double { x * x + y * y }
    var length: Double { lengthSquared.squareRoot() }

    func dot(_ other: Vec2) -> Double {
        x * other.x + y * other.y
    }

    func cross(_ other: Vec2) -> Double {
        x * other.y - y * other.x
    }

    func normalized(tolerance: Double = FFMath.eps) -> Vec2? {
        let length = self.length
        guard length > tolerance else { return nil }
        return self / length
    }

    func distance(to other: Vec2) -> Double {
        (self - other).length
    }

    func lerp(to other: Vec2, t: Double) -> Vec2 {
        self + (other - self) * t
    }

    static func + (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static prefix func - (value: Vec2) -> Vec2 {
        Vec2(x: -value.x, y: -value.y)
    }

    static func * (lhs: Vec2, rhs: Double) -> Vec2 {
        Vec2(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func * (lhs: Double, rhs: Vec2) -> Vec2 {
        rhs * lhs
    }

    static func / (lhs: Vec2, rhs: Double) -> Vec2 {
        Vec2(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

/// A point or direction in three-dimensional millimetre space.
struct Vec3: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vec3(x: 0, y: 0, z: 0)
    static let unitX = Vec3(x: 1, y: 0, z: 0)
    static let unitY = Vec3(x: 0, y: 1, z: 0)
    static let unitZ = Vec3(x: 0, y: 0, z: 1)

    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    var lengthSquared: Double { x * x + y * y + z * z }
    var length: Double { lengthSquared.squareRoot() }

    func dot(_ other: Vec3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Vec3) -> Vec3 {
        Vec3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    func normalized(tolerance: Double = FFMath.eps) -> Vec3? {
        let length = self.length
        guard length > tolerance else { return nil }
        return self / length
    }

    func distance(to other: Vec3) -> Double {
        (self - other).length
    }

    func lerp(to other: Vec3, t: Double) -> Vec3 {
        self + (other - self) * t
    }

    func componentMin(_ other: Vec3) -> Vec3 {
        Vec3(x: min(x, other.x), y: min(y, other.y), z: min(z, other.z))
    }

    func componentMax(_ other: Vec3) -> Vec3 {
        Vec3(x: max(x, other.x), y: max(y, other.y), z: max(z, other.z))
    }

    static func + (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static prefix func - (value: Vec3) -> Vec3 {
        Vec3(x: -value.x, y: -value.y, z: -value.z)
    }

    static func * (lhs: Vec3, rhs: Double) -> Vec3 {
        Vec3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    static func * (lhs: Double, rhs: Vec3) -> Vec3 {
        rhs * lhs
    }

    static func / (lhs: Vec3, rhs: Double) -> Vec3 {
        Vec3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}

/// A homogeneous point or direction.
struct Vec4: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double
    var w: Double

    static let zero = Vec4(x: 0, y: 0, z: 0, w: 0)

    init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    init(_ vector: Vec3, w: Double) {
        self.init(x: vector.x, y: vector.y, z: vector.z, w: w)
    }

    var xyz: Vec3 { Vec3(x: x, y: y, z: z) }
    var lengthSquared: Double { x * x + y * y + z * z + w * w }
    var length: Double { lengthSquared.squareRoot() }

    func dot(_ other: Vec4) -> Double {
        x * other.x + y * other.y + z * other.z + w * other.w
    }

    func normalized(tolerance: Double = FFMath.eps) -> Vec4? {
        let length = self.length
        guard length > tolerance else { return nil }
        return self / length
    }

    /// Converts a homogeneous point with a non-zero weight back to 3-D.
    /// A point at infinity has no affine position, so it is rejected.
    func perspectiveDivide(tolerance: Double = FFMath.eps) -> Vec3? {
        guard abs(w) > tolerance else { return nil }
        return xyz / w
    }

    static func + (lhs: Vec4, rhs: Vec4) -> Vec4 {
        Vec4(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z, w: lhs.w + rhs.w)
    }

    static func - (lhs: Vec4, rhs: Vec4) -> Vec4 {
        Vec4(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z, w: lhs.w - rhs.w)
    }

    static prefix func - (value: Vec4) -> Vec4 {
        Vec4(x: -value.x, y: -value.y, z: -value.z, w: -value.w)
    }

    static func * (lhs: Vec4, rhs: Double) -> Vec4 {
        Vec4(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs, w: lhs.w * rhs)
    }

    static func * (lhs: Double, rhs: Vec4) -> Vec4 {
        rhs * lhs
    }

    static func / (lhs: Vec4, rhs: Double) -> Vec4 {
        Vec4(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs, w: lhs.w / rhs)
    }
}
