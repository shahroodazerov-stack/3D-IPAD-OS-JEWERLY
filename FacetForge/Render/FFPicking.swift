import CoreGraphics
import Foundation

/// What a picked thing is. The filter is the jeweller-facing distinction:
/// a curve is a construct, a solid is metal, a stone is a gem.
enum FFPickKind: String, CaseIterable, Codable, Sendable {
    case curve
    case solid
    case stone
}

/// Which kinds a click may return. Filtering happens after the front-most
/// object is resolved, so a filtered-out object still occludes what is behind
/// it instead of letting the click fall through.
struct FFPickFilter: OptionSet, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let curve = FFPickFilter(rawValue: 1 << 0)
    static let solid = FFPickFilter(rawValue: 1 << 1)
    static let stone = FFPickFilter(rawValue: 1 << 2)
    static let all: FFPickFilter = [.curve, .solid, .stone]

    func allows(_ kind: FFPickKind) -> Bool {
        switch kind {
        case .curve: return contains(.curve)
        case .solid: return contains(.solid)
        case .stone: return contains(.stone)
        }
    }
}

/// A resolved pick. `pixel` is the top-left-origin pixel the hit came from so
/// a caller can grow a drag rectangle without re-resolving the hit.
struct FFPickResult: Equatable, Sendable {
    let nodeID: UUID
    let name: String
    let kind: FFPickKind
    let pixelX: Int
    let pixelY: Int
}

/// The GPU ID buffer. Index 0 means "nothing"; node `n` writes `n + 1`, so an
/// unrendered scene clears to zero without a separate sentinel.
struct FFPickingReadback: Equatable {
    let width: Int
    let height: Int
    let objectIDs: [UInt32]

    func objectID(atX x: Int, y: Int) -> UInt32 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return objectIDs[y * width + x]
    }

    /// The IDs in a square neighbourhood, used by tests to allow the one-pixel
    /// difference between Metal rasterisation and a CPU ray at a silhouette.
    func objectIDs(aroundX x: Int, y: Int, radius: Int) -> Set<UInt32> {
        var ids: Set<UInt32> = []
        for dy in -radius...radius {
            for dx in -radius...radius {
                ids.insert(objectID(atX: x + dx, y: y + dy))
            }
        }
        return ids
    }
}

/// Resolves a pixel from an ID buffer into a scene node. The mapping is by
/// node index, not by visibility, so hiding a node cannot shift another node's
/// ID.
enum FFPickResolver {
    static func resolve(
        buffer: FFPickingReadback,
        scene: FFViewportScene,
        point: Vec2,
        filter: FFPickFilter = .all
    ) -> FFPickResult? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        let raw = buffer.objectID(atX: x, y: y)
        guard raw > 0 else { return nil }
        let index = Int(raw) - 1
        guard index >= 0, index < scene.nodes.count else { return nil }
        let node = scene.nodes[index]
        guard node.isVisible, filter.allows(node.kind) else { return nil }
        return FFPickResult(
            nodeID: node.id,
            name: node.name,
            kind: node.kind,
            pixelX: x,
            pixelY: y
        )
    }
}

/// A curve as the picker sees it. Curves are not triangles, so they cannot
/// write to the ID buffer; they are picked analytically in screen space.
struct FFPickCurve: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var points: [Vec3]
    var isClosed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        points: [Vec3],
        isClosed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.points = points
        self.isClosed = isClosed
    }
}

/// The analytic fallback for curves and for hosts where the ID pass is not
/// available. Distances are in viewport points, matching the six-point target
/// a finger or Pencil needs.
enum FFCurvePicker {
    static func screenDistance(
        from point: Vec2,
        to curve: FFPickCurve,
        camera: FFCamera,
        viewport: Vec2
    ) -> Double? {
        guard curve.points.count >= 2, viewport.x > 0, viewport.y > 0 else { return nil }

        var projected: [Vec2] = []
        projected.reserveCapacity(curve.points.count + 1)
        for world in curve.points {
            guard let screen = camera.screenPoint(for: world, viewport: viewport) else {
                return nil
            }
            projected.append(screen)
        }
        if curve.isClosed, let first = projected.first {
            projected.append(first)
        }

        var best: Double?
        for index in 0..<(projected.count - 1) {
            let distance = distanceToSegment(
                point: point,
                start: projected[index],
                end: projected[index + 1]
            )
            if best.map({ distance < $0 }) ?? true {
                best = distance
            }
        }
        return best
    }

    static func pick(
        curves: [FFPickCurve],
        at point: Vec2,
        camera: FFCamera,
        viewport: Vec2,
        tolerance: Double = 6
    ) -> FFPickCurve? {
        guard tolerance >= 0 else { return nil }
        var best: (curve: FFPickCurve, distance: Double)?
        for curve in curves {
            guard let distance = screenDistance(
                from: point,
                to: curve,
                camera: camera,
                viewport: viewport
            ), distance <= tolerance else { continue }
            if best.map({ distance < $0.distance }) ?? true {
                best = (curve, distance)
            }
        }
        return best?.curve
    }

    private static func distanceToSegment(point: Vec2, start: Vec2, end: Vec2) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > FFMath.eps else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let t = FFMath.clamp(
            ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared,
            to: 0...1
        )
        let x = start.x + t * dx
        let y = start.y + t * dy
        return hypot(point.x - x, point.y - y)
    }
}

/// Hover and drag are a small state machine rather than scattered booleans:
/// a drag owns the highlight until it ends, so a hover event arriving from a
/// trackpad cannot steal the object being dragged.
enum FFPickPhase: Equatable {
    case idle
    case hovering(FFPickResult)
    case dragging(FFPickResult)
}

struct FFPickInteraction: Equatable {
    private(set) var phase: FFPickPhase = .idle

    var picked: FFPickResult? {
        switch phase {
        case .idle: return nil
        case .hovering(let result), .dragging(let result): return result
        }
    }

    mutating func hover(_ result: FFPickResult?) {
        if case .dragging = phase { return }
        phase = result.map(FFPickPhase.hovering) ?? .idle
    }

    @discardableResult
    mutating func beginDrag(_ result: FFPickResult?) -> Bool {
        guard let result else {
            endDrag()
            return false
        }
        phase = .dragging(result)
        return true
    }

    mutating func endDrag() {
        phase = .idle
    }
}
