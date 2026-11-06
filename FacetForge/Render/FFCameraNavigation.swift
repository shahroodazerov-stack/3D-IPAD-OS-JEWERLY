import Foundation

/// Phase 10's navigation rules. The viewport recognisers and the unit tests
/// both go through this type, so the touch sensitivity — not just the camera
/// maths — is part of the tested surface.
enum FFCameraNavigation {
    /// One point of drag rotates the turntable by 0.008 rad (0.46°). At the
    /// default 150 mm orbit that is roughly 1.2 mm of surface travel per point,
    /// which matches the direct-manipulation feel of the reference workflow.
    static let orbitRadiansPerPoint = 0.008

    /// Pinch factors outside this band are ignored rather than snapping the
    /// camera through several orders of magnitude in one event.
    static let pinchFactorRange = 0.2...5.0

    /// The empty-scene framing target. Phase 12 replaces this with the document
    /// bounds; until then the viewport frames the ring envelope the shell shows.
    static let jewelleryBounds = AABB(
        minimum: Vec3(x: -12, y: -9, z: -12),
        maximum: Vec3(x: 12, y: 9, z: 12)
    )

    /// Drag right spins the ring right: the camera orbits the other way, which
    /// is why yaw is negated. Dragging up raises the eye above the bench.
    static func orbit(_ camera: inout FFCamera, screenDelta: Vec2) {
        guard screenDelta.x.isFinite, screenDelta.y.isFinite else { return }
        camera.orbit(
            deltaYaw: -screenDelta.x * orbitRadiansPerPoint,
            deltaPitch: -screenDelta.y * orbitRadiansPerPoint
        )
    }

    /// Two-finger and trackpad drags move the target so the scene follows the
    /// fingers one-to-one at the target plane.
    static func pan(_ camera: inout FFCamera, screenDelta: Vec2, viewport: Vec2) {
        camera.pan(screenDelta: screenDelta, viewport: viewport)
    }

    /// Pinch zoom around the gesture centroid.
    static func zoom(
        _ camera: inout FFCamera,
        factor: Double,
        around anchor: Vec2,
        viewport: Vec2
    ) {
        guard factor.isFinite,
              pinchFactorRange.contains(factor),
              viewport.x > FFMath.eps,
              viewport.y > FFMath.eps
        else { return }
        camera.zoom(by: factor, around: anchor, viewport: viewport)
    }

    /// Frames the current jewellery envelope with headroom on every side.
    static func frameAll(_ camera: inout FFCamera) {
        camera.frame(bounds: jewelleryBounds, padding: 1.25)
    }

    /// Which named orientation, if any, the camera currently sits on. The
    /// comparison is tolerant because orbit deltas accumulate in floating
    /// point, but it is only used for HUD labelling, never for behaviour.
    static func namedView(for camera: FFCamera) -> FFNamedView? {
        FFNamedView.allCases.first { view in
            abs(camera.yaw - view.yaw) < 1e-9 && abs(camera.pitch - view.pitch) < 1e-9
        }
    }
}
