import Foundation

/// A unit quaternion representing a rotation.
struct Quat: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double
    var w: Double

    static let identity = Quat(x: 0, y: 0, z: 0, w: 1)

    init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    /// Builds a rotation from a non-degenerate axis. A zero-length axis has no
    /// defined rotation plane, so it is rejected rather than silently becoming
    /// an identity rotation.
    init?(axis: Vec3, angle: Double) {
        guard let axis = axis.normalized() else { return nil }
        let halfAngle = angle * 0.5
        let sine = sin(halfAngle)
        self.init(
            x: axis.x * sine,
            y: axis.y * sine,
            z: axis.z * sine,
            w: cos(halfAngle)
        )
    }

    var lengthSquared: Double { x * x + y * y + z * z + w * w }
    var length: Double { lengthSquared.squareRoot() }

    var conjugate: Quat { Quat(x: -x, y: -y, z: -z, w: w) }

    func normalized(tolerance: Double = FFMath.eps) -> Quat? {
        let length = self.length
        guard length > tolerance else { return nil }
        return Quat(x: x / length, y: y / length, z: z / length, w: w / length)
    }

    /// Returns the multiplicative inverse for any non-zero quaternion.
    func inverse(tolerance: Double = FFMath.eps) -> Quat? {
        let normSquared = lengthSquared
        guard normSquared > tolerance else { return nil }
        let scale = 1 / normSquared
        return Quat(x: -x * scale, y: -y * scale, z: -z * scale, w: w * scale)
    }

    /// Rotates a vector. For a unit quaternion this is a rigid rotation.
    func rotated(_ vector: Vec3) -> Vec3 {
        let point = Quat(x: vector.x, y: vector.y, z: vector.z, w: 0)
        let result = self * point * conjugate
        return Vec3(x: result.x, y: result.y, z: result.z)
    }

    /// The equivalent row-major rotation matrix for a unit quaternion.
    func toMat3() -> Mat3 {
        let xx = x * x
        let yy = y * y
        let zz = z * z
        let xy = x * y
        let xz = x * z
        let yz = y * z
        let xw = x * w
        let yw = y * w
        let zw = z * w

        return Mat3(
            m00: 1 - 2 * (yy + zz), m01: 2 * (xy - zw), m02: 2 * (xz + yw),
            m10: 2 * (xy + zw), m11: 1 - 2 * (xx + zz), m12: 2 * (yz - xw),
            m20: 2 * (xz - yw), m21: 2 * (yz + xw), m22: 1 - 2 * (xx + yy)
        )
    }

    static func * (lhs: Quat, rhs: Quat) -> Quat {
        Quat(
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
        )
    }
}

/// A plane in Hessian normal form: `normal · point = offset`.
struct Plane: Equatable, Sendable {
    let normal: Vec3
    let offset: Double

    /// A degenerate normal has no plane, so the initializer fails.
    init?(normal: Vec3, point: Vec3) {
        guard let unitNormal = normal.normalized() else { return nil }
        self.normal = unitNormal
        self.offset = unitNormal.dot(point)
    }

    init?(normal: Vec3, offset: Double) {
        let length = normal.length
        guard length > FFMath.eps else { return nil }
        self.normal = normal / length
        // The offset is part of the same equation, so it must be divided by
        // the same scale as the normal.
        self.offset = offset / length
    }

    func signedDistance(to point: Vec3) -> Double {
        normal.dot(point) - offset
    }

    func project(_ point: Vec3) -> Vec3 {
        point - normal * signedDistance(to: point)
    }

    func mirrored(_ point: Vec3) -> Vec3 {
        point - normal * (2 * signedDistance(to: point))
    }
}

/// A ray with a normalized direction.
struct Ray: Equatable, Sendable {
    let origin: Vec3
    let direction: Vec3

    init?(origin: Vec3, direction: Vec3) {
        guard let unitDirection = direction.normalized() else { return nil }
        self.origin = origin
        self.direction = unitDirection
    }

    func point(at distance: Double) -> Vec3 {
        origin + direction * distance
    }

    /// Returns the ray parameter at the plane intersection, or `nil` when the
    /// ray is parallel or the plane is behind the origin.
    func intersection(with plane: Plane) -> Double? {
        let denominator = direction.dot(plane.normal)
        guard abs(denominator) > FFMath.eps else { return nil }
        let distance = (plane.offset - origin.dot(plane.normal)) / denominator
        guard distance >= -FFMath.eps else { return nil }
        return max(0, distance)
    }

    /// Slab intersection. A degenerate box is still a valid zero-volume box.
    func intersection(with box: AABB) -> Double? {
        let origins = [origin.x, origin.y, origin.z]
        let directions = [direction.x, direction.y, direction.z]
        let minimums = [box.minimum.x, box.minimum.y, box.minimum.z]
        let maximums = [box.maximum.x, box.maximum.y, box.maximum.z]

        var near = -Double.infinity
        var far = Double.infinity

        for axis in 0..<3 {
            let axisOrigin = origins[axis]
            let axisDirection = directions[axis]
            let minimum = minimums[axis]
            let maximum = maximums[axis]

            if abs(axisDirection) <= FFMath.eps {
                if axisOrigin < minimum - FFMath.eps || axisOrigin > maximum + FFMath.eps {
                    return nil
                }
                continue
            }

            var first = (minimum - axisOrigin) / axisDirection
            var second = (maximum - axisOrigin) / axisDirection
            if first > second {
                swap(&first, &second)
            }
            near = max(near, first)
            far = min(far, second)
            if near > far {
                return nil
            }
        }

        guard far >= 0 else { return nil }
        return max(near, 0)
    }
}

/// An axis-aligned bounding box with canonical minimum and maximum corners.
struct AABB: Equatable, Sendable {
    let minimum: Vec3
    let maximum: Vec3

    init(minimum: Vec3, maximum: Vec3) {
        self.minimum = minimum.componentMin(maximum)
        self.maximum = minimum.componentMax(maximum)
    }

    var size: Vec3 { maximum - minimum }
    var center: Vec3 { (minimum + maximum) * 0.5 }

    func contains(_ point: Vec3, tolerance: Double = FFMath.eps) -> Bool {
        point.x >= minimum.x - tolerance && point.x <= maximum.x + tolerance
            && point.y >= minimum.y - tolerance && point.y <= maximum.y + tolerance
            && point.z >= minimum.z - tolerance && point.z <= maximum.z + tolerance
    }

    func intersects(_ other: AABB, tolerance: Double = FFMath.eps) -> Bool {
        maximum.x >= other.minimum.x - tolerance && minimum.x <= other.maximum.x + tolerance
            && maximum.y >= other.minimum.y - tolerance && minimum.y <= other.maximum.y + tolerance
            && maximum.z >= other.minimum.z - tolerance && minimum.z <= other.maximum.z + tolerance
    }

    func union(_ other: AABB) -> AABB {
        AABB(
            minimum: minimum.componentMin(other.minimum),
            maximum: maximum.componentMax(other.maximum)
        )
    }

    func expanded(by amount: Double) -> AABB {
        let offset = Vec3(x: amount, y: amount, z: amount)
        return AABB(minimum: minimum - offset, maximum: maximum + offset)
    }

    func rayIntersection(_ ray: Ray) -> Double? {
        ray.intersection(with: self)
    }
}
