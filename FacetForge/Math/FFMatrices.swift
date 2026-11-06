import Foundation

/// A 3×3 linear transform stored in row-major order.
struct Mat3: Equatable, Sendable {
    var m00: Double
    var m01: Double
    var m02: Double
    var m10: Double
    var m11: Double
    var m12: Double
    var m20: Double
    var m21: Double
    var m22: Double

    init(
        m00: Double, m01: Double, m02: Double,
        m10: Double, m11: Double, m12: Double,
        m20: Double, m21: Double, m22: Double
    ) {
        self.m00 = m00
        self.m01 = m01
        self.m02 = m02
        self.m10 = m10
        self.m11 = m11
        self.m12 = m12
        self.m20 = m20
        self.m21 = m21
        self.m22 = m22
    }

    init() {
        self = .identity
    }

    static let identity = Mat3(
        m00: 1, m01: 0, m02: 0,
        m10: 0, m11: 1, m12: 0,
        m20: 0, m21: 0, m22: 1
    )

    static func scale(x: Double, y: Double, z: Double) -> Mat3 {
        Mat3(
            m00: x, m01: 0, m02: 0,
            m10: 0, m11: y, m12: 0,
            m20: 0, m21: 0, m22: z
        )
    }

    static func rotationZ(_ angle: Double) -> Mat3 {
        let cosine = cos(angle)
        let sine = sin(angle)
        return Mat3(
            m00: cosine, m01: -sine, m02: 0,
            m10: sine, m11: cosine, m12: 0,
            m20: 0, m21: 0, m22: 1
        )
    }

    var transposed: Mat3 {
        Mat3(
            m00: m00, m01: m10, m02: m20,
            m10: m01, m11: m11, m12: m21,
            m20: m02, m21: m12, m22: m22
        )
    }

    var determinant: Double {
        m00 * (m11 * m22 - m12 * m21)
            - m01 * (m10 * m22 - m12 * m20)
            + m02 * (m10 * m21 - m11 * m20)
    }

    func inverse(tolerance: Double = FFMath.eps) -> Mat3? {
        let determinant = self.determinant
        guard abs(determinant) > tolerance else { return nil }
        let scale = 1 / determinant
        return Mat3(
            m00: (m11 * m22 - m12 * m21) * scale,
            m01: (m02 * m21 - m01 * m22) * scale,
            m02: (m01 * m12 - m02 * m11) * scale,
            m10: (m12 * m20 - m10 * m22) * scale,
            m11: (m00 * m22 - m02 * m20) * scale,
            m12: (m02 * m10 - m00 * m12) * scale,
            m20: (m10 * m21 - m11 * m20) * scale,
            m21: (m01 * m20 - m00 * m21) * scale,
            m22: (m00 * m11 - m01 * m10) * scale
        )
    }

    func maximumAbsoluteDifference(from other: Mat3) -> Double {
        let differences = [
            m00 - other.m00, m01 - other.m01, m02 - other.m02,
            m10 - other.m10, m11 - other.m11, m12 - other.m12,
            m20 - other.m20, m21 - other.m21, m22 - other.m22,
        ]
        return differences.map(abs).max() ?? 0
    }

    static func * (lhs: Mat3, rhs: Mat3) -> Mat3 {
        Mat3(
            m00: lhs.m00 * rhs.m00 + lhs.m01 * rhs.m10 + lhs.m02 * rhs.m20,
            m01: lhs.m00 * rhs.m01 + lhs.m01 * rhs.m11 + lhs.m02 * rhs.m21,
            m02: lhs.m00 * rhs.m02 + lhs.m01 * rhs.m12 + lhs.m02 * rhs.m22,
            m10: lhs.m10 * rhs.m00 + lhs.m11 * rhs.m10 + lhs.m12 * rhs.m20,
            m11: lhs.m10 * rhs.m01 + lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21,
            m12: lhs.m10 * rhs.m02 + lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22,
            m20: lhs.m20 * rhs.m00 + lhs.m21 * rhs.m10 + lhs.m22 * rhs.m20,
            m21: lhs.m20 * rhs.m01 + lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21,
            m22: lhs.m20 * rhs.m02 + lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22
        )
    }

    static func * (lhs: Mat3, rhs: Vec3) -> Vec3 {
        Vec3(
            x: lhs.m00 * rhs.x + lhs.m01 * rhs.y + lhs.m02 * rhs.z,
            y: lhs.m10 * rhs.x + lhs.m11 * rhs.y + lhs.m12 * rhs.z,
            z: lhs.m20 * rhs.x + lhs.m21 * rhs.y + lhs.m22 * rhs.z
        )
    }
}

/// A 4×4 affine transform stored in row-major order.
///
/// The last row is `(0, 0, 0, 1)` for every transform built here. The inverse
/// is a general Gauss–Jordan inverse so it also rejects singular matrices
/// instead of returning a plausible-looking transform.
struct Mat4: Equatable, Sendable {
    var m00: Double
    var m01: Double
    var m02: Double
    var m03: Double
    var m10: Double
    var m11: Double
    var m12: Double
    var m13: Double
    var m20: Double
    var m21: Double
    var m22: Double
    var m23: Double
    var m30: Double
    var m31: Double
    var m32: Double
    var m33: Double

    init(
        m00: Double, m01: Double, m02: Double, m03: Double,
        m10: Double, m11: Double, m12: Double, m13: Double,
        m20: Double, m21: Double, m22: Double, m23: Double,
        m30: Double, m31: Double, m32: Double, m33: Double
    ) {
        self.m00 = m00
        self.m01 = m01
        self.m02 = m02
        self.m03 = m03
        self.m10 = m10
        self.m11 = m11
        self.m12 = m12
        self.m13 = m13
        self.m20 = m20
        self.m21 = m21
        self.m22 = m22
        self.m23 = m23
        self.m30 = m30
        self.m31 = m31
        self.m32 = m32
        self.m33 = m33
    }

    init() {
        self = .identity
    }

    static let identity = Mat4(
        m00: 1, m01: 0, m02: 0, m03: 0,
        m10: 0, m11: 1, m12: 0, m13: 0,
        m20: 0, m21: 0, m22: 1, m23: 0,
        m30: 0, m31: 0, m32: 0, m33: 1
    )

    static func translation(_ offset: Vec3) -> Mat4 {
        Mat4(
            m00: 1, m01: 0, m02: 0, m03: offset.x,
            m10: 0, m11: 1, m12: 0, m13: offset.y,
            m20: 0, m21: 0, m22: 1, m23: offset.z,
            m30: 0, m31: 0, m32: 0, m33: 1
        )
    }

    static func scale(x: Double, y: Double, z: Double) -> Mat4 {
        Mat4(
            m00: x, m01: 0, m02: 0, m03: 0,
            m10: 0, m11: y, m12: 0, m13: 0,
            m20: 0, m21: 0, m22: z, m23: 0,
            m30: 0, m31: 0, m32: 0, m33: 1
        )
    }

    static func rotationX(_ angle: Double) -> Mat4 {
        let cosine = cos(angle)
        let sine = sin(angle)
        return Mat4(
            m00: 1, m01: 0, m02: 0, m03: 0,
            m10: 0, m11: cosine, m12: -sine, m13: 0,
            m20: 0, m21: sine, m22: cosine, m23: 0,
            m30: 0, m31: 0, m32: 0, m33: 1
        )
    }

    static func rotationY(_ angle: Double) -> Mat4 {
        let cosine = cos(angle)
        let sine = sin(angle)
        return Mat4(
            m00: cosine, m01: 0, m02: sine, m03: 0,
            m10: 0, m11: 1, m12: 0, m13: 0,
            m20: -sine, m21: 0, m22: cosine, m23: 0,
            m30: 0, m31: 0, m32: 0, m33: 1
        )
    }

    static func rotationZ(_ angle: Double) -> Mat4 {
        let cosine = cos(angle)
        let sine = sin(angle)
        return Mat4(
            m00: cosine, m01: -sine, m02: 0, m03: 0,
            m10: sine, m11: cosine, m12: 0, m13: 0,
            m20: 0, m21: 0, m22: 1, m23: 0,
            m30: 0, m31: 0, m32: 0, m33: 1
        )
    }

    func transformedPoint(_ point: Vec3) -> Vec3 {
        Vec3(
            x: m00 * point.x + m01 * point.y + m02 * point.z + m03,
            y: m10 * point.x + m11 * point.y + m12 * point.z + m13,
            z: m20 * point.x + m21 * point.y + m22 * point.z + m23
        )
    }

    func transformedVector(_ vector: Vec3) -> Vec3 {
        Vec3(
            x: m00 * vector.x + m01 * vector.y + m02 * vector.z,
            y: m10 * vector.x + m11 * vector.y + m12 * vector.z,
            z: m20 * vector.x + m21 * vector.y + m22 * vector.z
        )
    }

    func inverse(tolerance: Double = FFMath.eps) -> Mat4? {
        var coefficients: [[Double]] = [
            [m00, m01, m02, m03],
            [m10, m11, m12, m13],
            [m20, m21, m22, m23],
            [m30, m31, m32, m33],
        ]
        var result: [[Double]] = [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ]

        for column in 0..<4 {
            var pivotRow = column
            var pivotMagnitude = abs(coefficients[column][column])
            for row in (column + 1)..<4 {
                let magnitude = abs(coefficients[row][column])
                if magnitude > pivotMagnitude {
                    pivotRow = row
                    pivotMagnitude = magnitude
                }
            }
            guard pivotMagnitude > tolerance else { return nil }

            if pivotRow != column {
                coefficients.swapAt(pivotRow, column)
                result.swapAt(pivotRow, column)
            }

            let divisor = coefficients[column][column]
            for index in 0..<4 {
                coefficients[column][index] /= divisor
                result[column][index] /= divisor
            }

            for row in 0..<4 where row != column {
                // Eliminate even a tiny factor. Skipping values just above the
                // pivot tolerance would leave a residual in the inverse, which
                // is exactly the kind of error the 1e-12 round-trip test hunts.
                let factor = coefficients[row][column]
                for index in 0..<4 {
                    coefficients[row][index] -= factor * coefficients[column][index]
                    result[row][index] -= factor * result[column][index]
                }
            }
        }

        return Mat4(
            m00: result[0][0], m01: result[0][1], m02: result[0][2], m03: result[0][3],
            m10: result[1][0], m11: result[1][1], m12: result[1][2], m13: result[1][3],
            m20: result[2][0], m21: result[2][1], m22: result[2][2], m23: result[2][3],
            m30: result[3][0], m31: result[3][1], m32: result[3][2], m33: result[3][3]
        )
    }

    func maximumAbsoluteDifference(from other: Mat4) -> Double {
        let differences = [
            m00 - other.m00, m01 - other.m01, m02 - other.m02, m03 - other.m03,
            m10 - other.m10, m11 - other.m11, m12 - other.m12, m13 - other.m13,
            m20 - other.m20, m21 - other.m21, m22 - other.m22, m23 - other.m23,
            m30 - other.m30, m31 - other.m31, m32 - other.m32, m33 - other.m33,
        ]
        return differences.map(abs).max() ?? 0
    }

    static func * (lhs: Mat4, rhs: Mat4) -> Mat4 {
        Mat4(
            m00: lhs.m00 * rhs.m00 + lhs.m01 * rhs.m10 + lhs.m02 * rhs.m20 + lhs.m03 * rhs.m30,
            m01: lhs.m00 * rhs.m01 + lhs.m01 * rhs.m11 + lhs.m02 * rhs.m21 + lhs.m03 * rhs.m31,
            m02: lhs.m00 * rhs.m02 + lhs.m01 * rhs.m12 + lhs.m02 * rhs.m22 + lhs.m03 * rhs.m32,
            m03: lhs.m00 * rhs.m03 + lhs.m01 * rhs.m13 + lhs.m02 * rhs.m23 + lhs.m03 * rhs.m33,
            m10: lhs.m10 * rhs.m00 + lhs.m11 * rhs.m10 + lhs.m12 * rhs.m20 + lhs.m13 * rhs.m30,
            m11: lhs.m10 * rhs.m01 + lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21 + lhs.m13 * rhs.m31,
            m12: lhs.m10 * rhs.m02 + lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22 + lhs.m13 * rhs.m32,
            m13: lhs.m10 * rhs.m03 + lhs.m11 * rhs.m13 + lhs.m12 * rhs.m23 + lhs.m13 * rhs.m33,
            m20: lhs.m20 * rhs.m00 + lhs.m21 * rhs.m10 + lhs.m22 * rhs.m20 + lhs.m23 * rhs.m30,
            m21: lhs.m20 * rhs.m01 + lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21 + lhs.m23 * rhs.m31,
            m22: lhs.m20 * rhs.m02 + lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22 + lhs.m23 * rhs.m32,
            m23: lhs.m20 * rhs.m03 + lhs.m21 * rhs.m13 + lhs.m22 * rhs.m23 + lhs.m23 * rhs.m33,
            m30: lhs.m30 * rhs.m00 + lhs.m31 * rhs.m10 + lhs.m32 * rhs.m20 + lhs.m33 * rhs.m30,
            m31: lhs.m30 * rhs.m01 + lhs.m31 * rhs.m11 + lhs.m32 * rhs.m21 + lhs.m33 * rhs.m31,
            m32: lhs.m30 * rhs.m02 + lhs.m31 * rhs.m12 + lhs.m32 * rhs.m22 + lhs.m33 * rhs.m32,
            m33: lhs.m30 * rhs.m03 + lhs.m31 * rhs.m13 + lhs.m32 * rhs.m23 + lhs.m33 * rhs.m33
        )
    }

    static func * (lhs: Mat4, rhs: Vec4) -> Vec4 {
        Vec4(
            x: lhs.m00 * rhs.x + lhs.m01 * rhs.y + lhs.m02 * rhs.z + lhs.m03 * rhs.w,
            y: lhs.m10 * rhs.x + lhs.m11 * rhs.y + lhs.m12 * rhs.z + lhs.m13 * rhs.w,
            z: lhs.m20 * rhs.x + lhs.m21 * rhs.y + lhs.m22 * rhs.z + lhs.m23 * rhs.w,
            w: lhs.m30 * rhs.x + lhs.m31 * rhs.y + lhs.m32 * rhs.z + lhs.m33 * rhs.w
        )
    }
}
