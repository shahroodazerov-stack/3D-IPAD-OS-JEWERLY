import Foundation

/// A validated quality setting for a tessellation pass.
///
/// Distances are millimetres and angles are radians. A zero or negative
/// tolerance is rejected rather than silently replaced, because a caller that
/// asks for an impossible tolerance should see the error at the settings
/// boundary, not as a tessellation that quietly violates the contract.
struct TessellationSettings: Equatable, Sendable {
    let chordalTolerance: Double
    let angularTolerance: Double
    let maximumSegments: Int

    init?(
        chordalTolerance: Double,
        angularTolerance: Double,
        maximumSegments: Int
    ) {
        guard chordalTolerance.isFinite, chordalTolerance > 0 else { return nil }
        guard angularTolerance.isFinite, angularTolerance > 0, angularTolerance <= .pi else {
            return nil
        }
        guard maximumSegments >= 3, maximumSegments <= 1_000_000 else { return nil }

        self.chordalTolerance = chordalTolerance
        self.angularTolerance = angularTolerance
        self.maximumSegments = maximumSegments
    }

    /// The interactive viewport preset. It favours a low triangle count while
    /// keeping a 10 mm radius visually smooth.
    static let display = preset(
        chordalTolerance: 0.05,
        angularTolerance: FFMath.radians(10),
        maximumSegments: 4_096
    )

    /// The manufacturing/export preset. It is used when the result leaves the
    /// app and is therefore held to a much tighter chordal budget.
    static let export = preset(
        chordalTolerance: 0.005,
        angularTolerance: FFMath.radians(2),
        maximumSegments: 16_384
    )

    private static func preset(
        chordalTolerance: Double,
        angularTolerance: Double,
        maximumSegments: Int
    ) -> TessellationSettings {
        guard let settings = TessellationSettings(
            chordalTolerance: chordalTolerance,
            angularTolerance: angularTolerance,
            maximumSegments: maximumSegments
        ) else {
            preconditionFailure("built-in tessellation preset must be valid")
        }
        return settings
    }
}

/// The two levels of detail the Phase 8 pipeline exposes.
enum TessellationLOD: String, CaseIterable, Equatable, Sendable {
    case display
    case export

    var settings: TessellationSettings {
        switch self {
        case .display: return TessellationSettings.display
        case .export: return TessellationSettings.export
        }
    }

    var label: String {
        switch self {
        case .display: return "Display"
        case .export: return "Export"
        }
    }
}

/// A flattened 2-D path in millimetres.
///
/// A closed path stores each vertex once: the closing edge is implied from the
/// last point back to the first. This is the same convention the mesh kernel
/// uses for a polygon cap.
struct TessellatedPath2D: Equatable, Sendable {
    let points: [Vec2]
    let isClosed: Bool

    /// True when every accepted segment met the requested chordal and angular
    /// tolerance. A maximum-segment cap can force a coarser path, in which case
    /// this is false rather than silently claiming success.
    let toleranceMet: Bool

    init?(points: [Vec2], isClosed: Bool, toleranceMet: Bool) {
        let minimumPoints = isClosed ? 3 : 2
        guard points.count >= minimumPoints else { return nil }
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }

        self.points = points
        self.isClosed = isClosed
        self.toleranceMet = toleranceMet
    }

    var segmentCount: Int {
        isClosed ? points.count : max(0, points.count - 1)
    }

    /// A simple polygon fan has `n - 2` triangles. An open path has no fill.
    var triangleCount: Int {
        isClosed ? max(0, points.count - 2) : 0
    }

    var length: Double {
        let edgeCount = isClosed ? points.count : points.count - 1
        guard edgeCount > 0 else { return 0 }
        var total = 0.0
        for index in 0..<edgeCount {
            total += points[index].distance(to: points[(index + 1) % points.count])
        }
        return total
    }

    /// The shortest distance from a query point to any edge, including the
    /// closing edge of a closed path.
    func distance(to query: Vec2) -> Double {
        let edgeCount = isClosed ? points.count : points.count - 1
        guard edgeCount > 0 else { return .infinity }
        var closest = Double.infinity
        for index in 0..<edgeCount {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            closest = min(closest, TessellatedPath2D.distanceToSegment(query, start, end))
        }
        return closest
    }

    /// Measures the one-way deviation from a curve to this flattened path by
    /// sampling the curve and taking the furthest sample from the polyline.
    /// This is deliberately a measurement, not a claim: a caller can compare it
    /// with the tolerance that produced the path.
    func maximumDeviation(of curve: Curve2D, samples: Int = 512) -> Double {
        guard samples >= 2 else { return .infinity }
        var maximum = 0.0
        for index in 0...samples {
            let t = Double(index) / Double(samples)
            maximum = max(maximum, distance(to: curve.point(at: t)))
        }
        return maximum
    }

    private static func distanceToSegment(_ query: Vec2, _ start: Vec2, _ end: Vec2) -> Double {
        let edge = end - start
        let denominator = edge.lengthSquared
        guard denominator > 1e-24 else { return query.distance(to: start) }
        let parameter = FFMath.clamp((query - start).dot(edge) / denominator, to: 0...1)
        return query.distance(to: start + edge * parameter)
    }
}

/// Tracks how many triangles a caller is still allowed to emit.
///
/// A closed profile with `n` vertices uses `n - 2` triangles in a simple fan.
/// Keeping the budget in triangle units, rather than in path segments, means a
/// caller cannot accidentally spend a different unit than the renderer.
struct TriangleBudgetManager: Equatable, Sendable {
    let maximumTriangles: Int
    private(set) var usedTriangles: Int

    init(maximumTriangles: Int) {
        self.maximumTriangles = max(0, maximumTriangles)
        self.usedTriangles = 0
    }

    var remainingTriangles: Int {
        max(0, maximumTriangles - usedTriangles)
    }

    var isExhausted: Bool { remainingTriangles == 0 }

    /// Reserves up to `requested` triangles and returns what was granted.
    @discardableResult
    mutating func reserve(_ requested: Int) -> Int {
        guard requested > 0 else { return 0 }
        let granted = min(requested, remainingTriangles)
        usedTriangles += granted
        return granted
    }

    mutating func reset() {
        usedTriangles = 0
    }
}

/// Chordal and angular flattening plus the Phase 8 deviation measurements.
enum Tessellator {
    /// The number of equal arcs needed for a circle to satisfy both tolerances.
    ///
    /// The chordal term is `ceil(pi / acos(1 - tolerance / radius))`. For a
    /// 20 mm-diameter circle at 0.005 mm this is exactly 100, which is the
    /// Phase 8 acceptance fixture. The angular term can request more segments;
    /// the maximum-segment cap always wins last.
    static func circleSegmentCount(
        radius: Double,
        settings: TessellationSettings
    ) -> Int? {
        guard radius.isFinite, radius > 0 else { return nil }

        let ratio = 1 - settings.chordalTolerance / radius
        let chordalSegments: Int
        if ratio <= -1 {
            chordalSegments = 3
        } else {
            let angle = 2 * acos(FFMath.clamp(ratio, to: -1...1))
            if angle <= 0 {
                chordalSegments = settings.maximumSegments
            } else {
                let raw = (2 * .pi) / angle
                chordalSegments = raw >= Double(settings.maximumSegments)
                    ? settings.maximumSegments
                    : Int(ceil(raw))
            }
        }

        let angularRaw = (2 * .pi) / settings.angularTolerance
        let angularSegments = angularRaw >= Double(settings.maximumSegments)
            ? settings.maximumSegments
            : Int(ceil(angularRaw))

        return max(3, min(settings.maximumSegments, max(chordalSegments, angularSegments)))
    }

    /// The maximum sagitta of a regular polygon inscribed in a circle of
    /// `radius` with `segments` edges.
    static func circleDeviation(radius: Double, segments: Int) -> Double? {
        guard radius.isFinite, radius > 0, segments >= 3 else { return nil }
        return radius * (1 - cos(.pi / Double(segments)))
    }

    /// Flattens a circle into a closed, equal-angle polygon.
    static func tessellateCircle(
        center: Vec2 = .zero,
        radius: Double,
        settings: TessellationSettings
    ) -> TessellatedPath2D? {
        guard let segments = circleSegmentCount(radius: radius, settings: settings) else {
            return nil
        }
        return makeCircle(center: center, radius: radius, segments: segments, settings: settings)
    }

    /// Flattens a circle while charging the simple-polygon fan against a shared
    /// triangle budget. If the budget cannot afford at least one triangle the
    /// call returns `nil` without consuming budget.
    static func tessellateCircle(
        center: Vec2 = .zero,
        radius: Double,
        settings: TessellationSettings,
        budget: inout TriangleBudgetManager
    ) -> TessellatedPath2D? {
        guard let requestedSegments = circleSegmentCount(radius: radius, settings: settings) else {
            return nil
        }
        let requestedTriangles = max(1, requestedSegments - 2)
        guard budget.remainingTriangles >= 1 else { return nil }

        let granted = budget.reserve(requestedTriangles)
        guard granted >= 1 else { return nil }
        let segments = min(settings.maximumSegments, granted + 2)
        return makeCircle(center: center, radius: radius, segments: segments, settings: settings)
    }

    private static func makeCircle(
        center: Vec2,
        radius: Double,
        segments: Int,
        settings: TessellationSettings
    ) -> TessellatedPath2D? {
        guard segments >= 3, let deviation = circleDeviation(radius: radius, segments: segments) else {
            return nil
        }

        let step = (2 * .pi) / Double(segments)
        var points: [Vec2] = []
        points.reserveCapacity(segments)
        for index in 0..<segments {
            let angle = step * Double(index)
            points.append(Vec2(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }

        let angularMet = step <= settings.angularTolerance + 1e-12
        let chordalMet = deviation <= settings.chordalTolerance + 1e-12
        return TessellatedPath2D(
            points: points,
            isClosed: true,
            toleranceMet: chordalMet && angularMet
        )
    }

    /// Adaptive chordal/angular flattening for any Bézier or NURBS curve.
    ///
    /// Each candidate segment is sampled at quarter, middle and three-quarter
    /// parameter values, and the tangents at its ends bound the angular turn.
    /// The internal chordal threshold is half the requested tolerance, leaving
    /// headroom for the fact that three samples are not a proof of the exact
    /// maximum deviation. If the segment cap is reached, the coarser edge is
    /// kept and `toleranceMet` becomes false.
    static func tessellate(
        _ curve: Curve2D,
        settings: TessellationSettings
    ) -> TessellatedPath2D? {
        let start = curve.start
        let end = curve.end
        let isClosed = start.distance(to: end) <= 1e-7
        // One extra point is reserved for a closed path's duplicate endpoint,
        // which is removed after refinement. The same point budget therefore
        // bounds both open and closed segment counts.
        let maximumPoints = settings.maximumSegments + 1
        guard maximumPoints >= 3 else { return nil }

        var points = [start]
        var toleranceMet = true
        let chordalThreshold = settings.chordalTolerance * 0.5

        func sampledDeviation(
            from t0: Double,
            to t1: Double,
            start p0: Vec2,
            end p1: Vec2
        ) -> Double {
            let chord = p1 - p0
            let chordLength = chord.length
            var worst = 0.0
            for fraction in [0.25, 0.5, 0.75] {
                let point = curve.point(at: t0 + (t1 - t0) * fraction)
                let deviation: Double
                if chordLength <= 1e-12 {
                    deviation = point.distance(to: p0)
                } else {
                    deviation = abs((point - p0).cross(chord)) / chordLength
                }
                worst = max(worst, deviation)
            }
            return worst
        }

        func tangentTurn(from t0: Double, to t1: Double) -> Double {
            let first = curve.derivative(at: t0)
            let second = curve.derivative(at: t1)
            guard let firstUnit = first.normalized(), let secondUnit = second.normalized() else {
                return .pi
            }
            let cosine = FFMath.clamp(firstUnit.dot(secondUnit), to: -1...1)
            return acos(cosine)
        }

        func refine(
            _ t0: Double,
            _ t1: Double,
            _ p0: Vec2,
            _ p1: Vec2,
            _ depth: Int,
            _ pointBudget: Int
        ) {
            let deviation = sampledDeviation(from: t0, to: t1, start: p0, end: p1)
            let turn = tangentTurn(from: t0, to: t1)
            let withinTolerance = deviation <= chordalThreshold
                && turn <= settings.angularTolerance
            let canSplit = depth < 16 && pointBudget >= 2

            if withinTolerance || !canSplit {
                if !withinTolerance { toleranceMet = false }
                points.append(p1)
                return
            }

            // Split the remaining point budget between the two halves. The
            // right half's closing point is the parent's `p1`; the left half's
            // closing point is the shared middle point. Allocating the budget
            // explicitly, rather than checking `points.count` inside each
            // recursive call, prevents a sequence of right siblings from
            // overshooting the segment cap.
            let leftBudget = max(1, pointBudget / 2)
            let rightBudget = pointBudget - leftBudget
            let middle = (t0 + t1) * 0.5
            let middlePoint = curve.point(at: middle)
            refine(t0, middle, p0, middlePoint, depth + 1, leftBudget)
            refine(middle, t1, middlePoint, p1, depth + 1, rightBudget)
        }

        refine(0, 1, start, end, 0, maximumPoints - 1)

        if isClosed {
            points.removeLast()
        }
        guard points.count >= (isClosed ? 3 : 2) else { return nil }
        return TessellatedPath2D(
            points: points,
            isClosed: isClosed,
            toleranceMet: toleranceMet
        )
    }
}
