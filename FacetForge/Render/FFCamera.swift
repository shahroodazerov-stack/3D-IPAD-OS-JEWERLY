import Foundation

/// Which projection the viewport uses. Phase 10 adds the UI that flips this;
/// Phase 9 only needs both matrices to be correct and testable.
enum FFProjectionMode: String, CaseIterable, Sendable {
    case perspective
    case orthographic

    var label: String {
        switch self {
        case .perspective: "Perspective"
        case .orthographic: "Orthographic"
        }
    }
}

/// The orthonormal camera frame. Keeping it as a value makes the screen-space
/// pan and the shader matrix use exactly the same basis.
struct FFCameraBasis: Equatable, Sendable {
    let right: Vec3
    let up: Vec3
    let forward: Vec3
}

/// A turntable camera in millimetre world space.
///
/// `yaw` rotates around the world Y axis, `pitch` raises the eye above the
/// target, and `distance` is the orbit radius. The eye looks at `target` with
/// world up `(0, 1, 0)`. Both projections map the near plane to clip depth 0
/// and the far plane to clip depth 1, which is the Metal convention rather
/// than OpenGL's -1…1.
struct FFCamera: Equatable, Sendable {
    private(set) var target: Vec3
    private(set) var yaw: Double
    private(set) var pitch: Double
    private(set) var distance: Double
    private(set) var projection: FFProjectionMode
    private(set) var fieldOfView: Double
    private(set) var orthographicHeight: Double
    private(set) var nearClip: Double
    private(set) var farClip: Double

    static let pitchLimit = FFMath.radians(89)
    static let minimumDistance = 1.0
    static let maximumDistance = 10_000.0
    static let perspectiveFOVRange = FFMath.radians(5)...FFMath.radians(120)

    /// The default three-quarter jewellery view: slightly above the bench and
    /// turned so the ring reads as a solid rather than an elevation.
    static let standard = FFCamera(
        target: .zero,
        yaw: FFMath.radians(-35),
        pitch: FFMath.radians(28),
        distance: 150
    )

    init(
        target: Vec3 = .zero,
        yaw: Double = FFMath.radians(-35),
        pitch: Double = FFMath.radians(28),
        distance: Double = 150,
        projection: FFProjectionMode = .perspective,
        fieldOfViewDegrees: Double = 45,
        orthographicHeight: Double = 90,
        nearClip: Double = 0.05,
        farClip: Double = 5_000
    ) {
        self.target = target
        self.yaw = yaw.isFinite ? yaw : 0
        self.pitch = FFMath.clamp(
            pitch.isFinite ? pitch : 0,
            to: (-Self.pitchLimit)...Self.pitchLimit
        )
        self.distance = FFMath.clamp(
            distance.isFinite ? distance : 150,
            to: Self.minimumDistance...Self.maximumDistance
        )
        self.projection = projection
        self.fieldOfView = FFMath.clamp(
            FFMath.radians(fieldOfViewDegrees.isFinite ? fieldOfViewDegrees : 45),
            to: Self.perspectiveFOVRange
        )
        self.orthographicHeight = max(1, orthographicHeight.isFinite ? orthographicHeight : 90)
        let near = max(0.001, nearClip.isFinite ? nearClip : 0.05)
        self.nearClip = near
        self.farClip = max(near + 1, farClip.isFinite ? farClip : 5_000)
    }

    /// Unit vector from the target to the eye.
    var eyeDirection: Vec3 {
        let cosine = cos(pitch)
        return Vec3(
            x: sin(yaw) * cosine,
            y: sin(pitch),
            z: cos(yaw) * cosine
        )
    }

    var position: Vec3 {
        target + eyeDirection * distance
    }

    var basis: FFCameraBasis {
        let forward = (target - position).normalized()
            ?? Vec3(x: 0, y: 0, z: -1)
        let right = forward.cross(.unitY).normalized()
            ?? Vec3.unitX
        let up = right.cross(forward).normalized()
            ?? Vec3.unitY
        return FFCameraBasis(right: right, up: up, forward: forward)
    }

    /// Right-handed look-at matrix in the kernel's row-major convention.
    var viewMatrix: Mat4 {
        let eye = position
        let frame = basis
        let zAxis = -frame.forward
        return Mat4(
            m00: frame.right.x, m01: frame.right.y, m02: frame.right.z,
            m03: -frame.right.dot(eye),
            m10: frame.up.x, m11: frame.up.y, m12: frame.up.z,
            m13: -frame.up.dot(eye),
            m20: zAxis.x, m21: zAxis.y, m22: zAxis.z,
            m23: -zAxis.dot(eye),
            m30: 0, m31: 0, m32: 0, m33: 1
        )
    }

    func projectionMatrix(aspect: Double) -> Mat4 {
        let ratio = aspect.isFinite && aspect > FFMath.eps ? aspect : 1
        switch projection {
        case .perspective:
            let focal = 1 / tan(fieldOfView * 0.5)
            return Mat4(
                m00: focal / ratio, m01: 0, m02: 0, m03: 0,
                m10: 0, m11: focal, m12: 0, m13: 0,
                m20: 0, m21: 0, m22: farClip / (nearClip - farClip),
                m23: (nearClip * farClip) / (nearClip - farClip),
                m30: 0, m31: 0, m32: -1, m33: 0
            )
        case .orthographic:
            let halfHeight = orthographicHeight * 0.5
            let halfWidth = halfHeight * ratio
            return Mat4(
                m00: 1 / halfWidth, m01: 0, m02: 0, m03: 0,
                m10: 0, m11: 1 / halfHeight, m12: 0, m13: 0,
                m20: 0, m21: 0, m22: 1 / (nearClip - farClip),
                m23: nearClip / (nearClip - farClip),
                m30: 0, m31: 0, m32: 0, m33: 1
            )
        }
    }

    func viewProjectionMatrix(aspect: Double) -> Mat4 {
        projectionMatrix(aspect: aspect) * viewMatrix
    }

    /// Projects a world point into top-left-origin viewport pixels. Returns
    /// `nil` when the point is at or behind the eye plane.
    func screenPoint(for point: Vec3, viewport: Vec2) -> Vec2? {
        guard viewport.x > FFMath.eps, viewport.y > FFMath.eps else { return nil }
        let clip = viewProjectionMatrix(aspect: viewport.x / viewport.y)
            * Vec4(x: point.x, y: point.y, z: point.z, w: 1)
        guard clip.w > FFMath.eps, clip.w.isFinite else { return nil }

        let ndcX = clip.x / clip.w
        let ndcY = clip.y / clip.w
        guard ndcX.isFinite, ndcY.isFinite else { return nil }
        return Vec2(
            x: (ndcX * 0.5 + 0.5) * viewport.x,
            y: (1 - (ndcY * 0.5 + 0.5)) * viewport.y
        )
    }

    /// Builds a picking ray from a top-left-origin viewport pixel. The ray
    /// starts on the near plane, so its origin is stable in orthographic mode
    /// as well.
    func ray(at screenPoint: Vec2, viewport: Vec2) -> Ray? {
        guard viewport.x > FFMath.eps, viewport.y > FFMath.eps else { return nil }
        guard let inverse = viewProjectionMatrix(aspect: viewport.x / viewport.y).inverse() else {
            return nil
        }

        let ndcX = (screenPoint.x / viewport.x) * 2 - 1
        let ndcY = 1 - (screenPoint.y / viewport.y) * 2
        let near = inverse * Vec4(x: ndcX, y: ndcY, z: 0, w: 1)
        let far = inverse * Vec4(x: ndcX, y: ndcY, z: 1, w: 1)
        guard abs(near.w) > FFMath.eps, abs(far.w) > FFMath.eps else { return nil }

        let nearPoint = Vec3(x: near.x / near.w, y: near.y / near.w, z: near.z / near.w)
        let farPoint = Vec3(x: far.x / far.w, y: far.y / far.w, z: far.z / far.w)
        return Ray(origin: nearPoint, direction: farPoint - nearPoint)
    }

    mutating func orbit(deltaYaw: Double, deltaPitch: Double) {
        if deltaYaw.isFinite { yaw += deltaYaw }
        if deltaPitch.isFinite {
            pitch = FFMath.clamp(
                pitch + deltaPitch,
                to: (-Self.pitchLimit)...Self.pitchLimit
            )
        }
    }

    /// Positive `factor` zooms in by shortening the orbit radius.
    mutating func dolly(by factor: Double) {
        guard factor.isFinite, factor > FFMath.eps else { return }
        distance = FFMath.clamp(
            distance / factor,
            to: Self.minimumDistance...Self.maximumDistance
        )
    }

    /// Moves the target so the scene follows a drag by `screenDelta` points.
    mutating func pan(screenDelta: Vec2, viewport: Vec2) {
        guard viewport.y > FFMath.eps else { return }
        let worldPerPoint: Double
        switch projection {
        case .perspective:
            worldPerPoint = 2 * distance * tan(fieldOfView * 0.5) / viewport.y
        case .orthographic:
            worldPerPoint = orthographicHeight / viewport.y
        }
        let frame = basis
        target = target
            - frame.right * (screenDelta.x * worldPerPoint)
            + frame.up * (screenDelta.y * worldPerPoint)
    }

    /// Frames an axis-aligned box so every corner is inside the frustum with
    /// `padding` headroom. The perspective fit uses the bounding sphere, which
    /// is conservative for any view orientation.
    mutating func frame(bounds: AABB, padding: Double = 1.2) {
        let safePadding = max(1, padding.isFinite ? padding : 1.2)
        let radius = max(bounds.size.length * 0.5, 0.5)
        target = bounds.center

        let halfFOV = fieldOfView * 0.5
        let fitted = radius / max(sin(halfFOV), 0.01)
        distance = FFMath.clamp(
            fitted * safePadding,
            to: Self.minimumDistance...Self.maximumDistance
        )
        orthographicHeight = max(1, radius * 2 * safePadding)
    }

    mutating func setProjection(_ mode: FFProjectionMode) {
        projection = mode
    }
}
