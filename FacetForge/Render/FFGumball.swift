import CoreGraphics
import Foundation

/// The three things a jeweller does to a node with the gizmo.
enum FFGumballMode: String, CaseIterable, Identifiable, Sendable {
    case move
    case rotate
    case scale

    var id: String { rawValue }

    var label: String {
        switch self {
        case .move: return "Move"
        case .rotate: return "Rotate"
        case .scale: return "Scale"
        }
    }
}

enum FFGumballAxis: String, CaseIterable, Identifiable, Sendable {
    case x
    case y
    case z

    var id: String { rawValue }

    var label: String { rawValue.uppercased() }

    var direction: Vec3 {
        switch self {
        case .x: return Vec3(x: 1, y: 0, z: 0)
        case .y: return Vec3(x: 0, y: 1, z: 0)
        case .z: return Vec3(x: 0, y: 0, z: 1)
        }
    }
}

/// An axis handle or the tile between two axes. Plane handles are the reason
/// the constraint is a value rather than a mode flag: the drag maths needs to
/// know which two axes it may move on.
enum FFGumballConstraint: Equatable, Sendable {
    case axis(FFGumballAxis)
    case plane(FFGumballAxis, FFGumballAxis)

    var axes: [FFGumballAxis] {
        switch self {
        case .axis(let axis): return [axis]
        case .plane(let first, let second): return [first, second]
        }
    }
}

/// A gizmo transaction. The session owns the undo stack for the interaction so
/// a drag that is cancelled never leaves a half-step in history.
struct FFGumballSession: Equatable {
    struct Snapshot: Equatable {
        var transform: Mat4
        var pivot: Vec3
    }

    private(set) var nodeID: UUID?
    private(set) var transform: Mat4 = .identity
    private(set) var pivot: Vec3 = .zero
    private(set) var undoStack: [Snapshot] = []
    var mode: FFGumballMode = .move
    var snapStep: Double = 1
    private var dragOrigin: Snapshot?

    var canUndo: Bool { !undoStack.isEmpty }

    /// The pivot the current drag started from. A drag reports its total
    /// translation from the touch-down point, so it must keep projecting
    /// against the original pivot, not the one it is moving.
    var activePivot: Vec3 { dragOrigin?.pivot ?? pivot }

    mutating func select(nodeID: UUID, transform: Mat4, pivot: Vec3? = nil) {
        self.nodeID = nodeID
        self.transform = transform
        self.pivot = pivot ?? Self.translation(of: transform)
        undoStack.removeAll()
        dragOrigin = nil
    }

    mutating func beginDrag() {
        dragOrigin = Snapshot(transform: transform, pivot: pivot)
    }

    mutating func move(by delta: Vec3) {
        let step = snapStep
        let snapped = Vec3(
            x: Self.snapped(delta.x, step: step),
            y: Self.snapped(delta.y, step: step),
            z: Self.snapped(delta.z, step: step)
        )
        let base = dragOrigin?.transform ?? transform
        let origin = dragOrigin?.pivot ?? pivot
        transform = Mat4.translation(snapped) * base
        pivot = Vec3(
            x: origin.x + snapped.x,
            y: origin.y + snapped.y,
            z: origin.z + snapped.z
        )
    }

    mutating func rotate(around axis: FFGumballAxis, degrees: Double) {
        let angle = Self.snapped(degrees, step: 1)
        let base = dragOrigin?.transform ?? transform
        let origin = dragOrigin?.pivot ?? pivot
        let rotation: Mat4
        switch axis {
        case .x: rotation = Mat4.rotationX(angle * .pi / 180)
        case .y: rotation = Mat4.rotationY(angle * .pi / 180)
        case .z: rotation = Mat4.rotationZ(angle * .pi / 180)
        }
        transform = Mat4.translation(origin)
            * rotation
            * Mat4.translation(Vec3(x: -origin.x, y: -origin.y, z: -origin.z))
            * base
    }

    mutating func scale(around axis: FFGumballAxis, factor: Double) {
        let value = max(0.01, Self.snapped(factor, step: 0.01))
        let base = dragOrigin?.transform ?? transform
        let origin = dragOrigin?.pivot ?? pivot
        let scale = Mat4.scale(
            x: axis == .x ? value : 1,
            y: axis == .y ? value : 1,
            z: axis == .z ? value : 1
        )
        transform = Mat4.translation(origin)
            * scale
            * Mat4.translation(Vec3(x: -origin.x, y: -origin.y, z: -origin.z))
            * base
    }

    mutating func commitDrag() {
        guard let dragOrigin else { return }
        self.dragOrigin = nil
        guard dragOrigin.transform != transform || dragOrigin.pivot != pivot else { return }
        undoStack.append(dragOrigin)
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
    }

    /// Absolute numeric entry. One call is one undo step, so typing a value and
    /// dragging share the same history.
    mutating func setTranslation(x: Double? = nil, y: Double? = nil, z: Double? = nil) {
        var next = transform
        if let x, x.isFinite { next.m03 = x }
        if let y, y.isFinite { next.m13 = y }
        if let z, z.isFinite { next.m23 = z }
        guard next != transform else { return }
        undoStack.append(Snapshot(transform: transform, pivot: pivot))
        transform = next
        pivot = Self.translation(of: next)
    }

    /// Editing the pivot changes where the gizmo lives, not the geometry.
    mutating func setPivot(_ next: Vec3) {
        guard next.x.isFinite, next.y.isFinite, next.z.isFinite else { return }
        pivot = next
    }

    @discardableResult
    mutating func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        transform = previous.transform
        pivot = previous.pivot
        dragOrigin = nil
        return true
    }

    mutating func cycleSnap() {
        if snapStep < 0.5 {
            snapStep = 1
        } else if snapStep < 5 {
            snapStep = 5
        } else {
            snapStep = 0.1
        }
    }

    static func snapped(_ value: Double, step: Double) -> Double {
        guard value.isFinite, step > 0 else { return value }
        return (value / step).rounded() * step
    }

    static func translation(of transform: Mat4) -> Vec3 {
        Vec3(x: transform.m03, y: transform.m13, z: transform.m23)
    }
}

/// Screen-to-world conversion for the gizmo. The scale is measured by
/// projecting one known ten-millimetre segment at the pivot, which makes a
/// drag of that segment exactly ten millimetres before snapping and keeps the
/// gesture consistent in perspective and orthographic views.
enum FFGumballMath {
    static let axisLengthMillimetres: Double = 10

    static func axisScreenScale(
        axis: FFGumballAxis,
        pivot: Vec3,
        camera: FFCamera,
        viewport: Vec2
    ) -> (unit: Vec2, millimetresPerPoint: Double)? {
        guard let start = camera.screenPoint(for: pivot, viewport: viewport) else { return nil }
        let end = pivot + axis.direction * axisLengthMillimetres
        guard let tip = camera.screenPoint(for: end, viewport: viewport) else { return nil }
        let vector = Vec2(x: tip.x - start.x, y: tip.y - start.y)
        let length = vector.length
        guard length > 0.5, length.isFinite else { return nil }
        return (
            unit: Vec2(x: vector.x / length, y: vector.y / length),
            millimetresPerPoint: axisLengthMillimetres / length
        )
    }

    static func moveDelta(
        constraint: FFGumballConstraint,
        screenTranslation: CGSize,
        camera: FFCamera,
        pivot: Vec3,
        viewport: Vec2,
        snap: Double,
        axes: [FFGumballAxis]? = nil
    ) -> Vec3? {
        let drag = Vec2(x: Double(screenTranslation.width), y: Double(screenTranslation.height))
        var delta = Vec3(x: 0, y: 0, z: 0)
        var resolved = false

        for axis in axes ?? constraint.axes {
            guard let scale = axisScreenScale(
                axis: axis,
                pivot: pivot,
                camera: camera,
                viewport: viewport
            ) else { continue }
            let projected = drag.dot(scale.unit) * scale.millimetresPerPoint
            let value = FFGumballSession.snapped(projected, step: snap)
            delta = delta + axis.direction * value
            resolved = true
        }
        return resolved ? delta : nil
    }

    static func rotationDegrees(
        screenTranslation: CGSize,
        snap: Double = 1
    ) -> Double {
        FFGumballSession.snapped(Double(screenTranslation.width) * 0.5, step: snap)
    }

    static func scaleFactor(
        screenTranslation: CGSize
    ) -> Double {
        max(0.01, 1 + Double(screenTranslation.width) / 200)
    }
}
