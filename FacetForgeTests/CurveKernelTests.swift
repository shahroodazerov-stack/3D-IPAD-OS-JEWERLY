import XCTest
@testable import FacetForge

private struct CurveRandom {
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
}

private func assertClose(
    _ actual: Vec2,
    _ expected: Vec2,
    accuracy: Double,
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertLessThan(
        actual.distance(to: expected),
        accuracy,
        "actual \(actual), expected \(expected)",
        file: file,
        line: line
    )
}

/// A rational quadratic arc exact enough for a golden-length case. The middle
/// control point is the intersection of the end tangents and its weight is
/// cos(sweep / 2), which is the standard exact circle construction.
private func makeArc(radius: Double, startAngle: Double, sweep: Double) -> Curve2D {
    let start = Vec2(
        x: radius * cos(startAngle),
        y: radius * sin(startAngle)
    )
    let end = Vec2(
        x: radius * cos(startAngle + sweep),
        y: radius * sin(startAngle + sweep)
    )
    let middleAngle = startAngle + sweep * 0.5
    let weight = cos(sweep * 0.5)
    let control = Vec2(
        x: radius / weight * cos(middleAngle),
        y: radius / weight * sin(middleAngle)
    )
    guard let curve = NURBSCurve2D(
        degree: 2,
        controlPoints: [start, control, end],
        weights: [1, weight, 1],
        knots: [0, 0, 0, 1, 1, 1]
    ) else {
        fatalError("the golden arc did not satisfy the NURBS initializer")
    }
    return .nurbs(curve)
}

private func goldenCurves() -> [(name: String, curve: Curve2D, length: Double)] {
    var cases: [(name: String, curve: Curve2D, length: Double)] = []

    let lineEndpoints: [(Vec2, Vec2)] = [
        (Vec2(x: 0, y: 0), Vec2(x: 3, y: 4)),
        (Vec2(x: 0, y: 0), Vec2(x: 10, y: 0)),
        (Vec2(x: 2, y: 1), Vec2(x: 2, y: 8.5)),
        (Vec2(x: -1, y: -1), Vec2(x: 0, y: 0)),
        (Vec2(x: 4, y: 2), Vec2(x: -8, y: 7)),
    ]
    for (index, endpoints) in lineEndpoints.enumerated() {
        guard let curve = Bezier2D([endpoints.0, endpoints.1]) else {
            fatalError("a line failed the Bezier initializer")
        }
        cases.append((
            "line-\(index)",
            .bezier(curve),
            endpoints.0.distance(to: endpoints.1)
        ))
    }

    let straightQuadraticLengths = [2.0, 4.0, 6.0, 10.0, 15.0]
    for (index, length) in straightQuadraticLengths.enumerated() {
        guard let curve = Bezier2D([
            Vec2(x: 0, y: 0),
            Vec2(x: length * 0.5, y: 0),
            Vec2(x: length, y: 0),
        ]) else {
            fatalError("a straight quadratic failed the Bezier initializer")
        }
        cases.append(("quadratic-line-\(index)", .bezier(curve), length))
    }

    let arcs: [(radius: Double, start: Double, sweep: Double)] = [
        (1, 0, .pi / 6),
        (2, 0.2, .pi / 4),
        (3, 1.0, .pi / 3),
        (4.5, 2.0, .pi / 2),
        (5, -1.0, 2 * .pi / 3),
        (0.5, 0.3, 5 * .pi / 6),
        (10, 1.2, .pi / 12),
        (7.5, -2.0, 3 * .pi / 4),
        (2.5, 0.7, .pi / 5),
        (12, 2.5, 5 * .pi / 6),
    ]
    for (index, arc) in arcs.enumerated() {
        cases.append((
            "arc-\(index)",
            makeArc(radius: arc.radius, startAngle: arc.start, sweep: arc.sweep),
            arc.radius * arc.sweep
        ))
    }

    return cases
}

final class CurveKernelTests: XCTestCase {
    func testTwentyGoldenCurvesMatchAnalyticLength() {
        let cases = goldenCurves()
        XCTAssertEqual(cases.count, 20)

        var failures: [String] = []
        var worstError = 0.0
        for item in cases {
            let actual = item.curve.arcLength(tolerance: 1e-10)
            let error = abs(actual - item.length)
            worstError = max(worstError, error)
            if error > 1e-6 {
                failures.append(
                    "\(item.name): got \(actual), expected \(item.length), error \(error)"
                )
            }
        }
        XCTAssertTrue(
            failures.isEmpty,
            "golden curves outside 1e-6:\n\(failures.joined(separator: "\n"))"
        )
        XCTAssertLessThan(worstError, 1e-6)
    }

    func testBezierSplitMatchesTheOriginalParameterisation() throws {
        guard let original = Bezier2D([
            Vec2(x: 0, y: 0),
            Vec2(x: 1, y: 2),
            Vec2(x: 3, y: 2),
            Vec2(x: 4, y: 0),
        ]) else {
            XCTFail("the cubic failed the Bezier initializer")
            return
        }
        let split = original.split(at: 0.37)

        for parameter in [0.0, 0.1, 0.37, 0.75, 1.0] {
            assertClose(
                split.0.point(at: parameter),
                original.point(at: 0.37 * parameter),
                accuracy: 1e-12
            )
            assertClose(
                split.1.point(at: parameter),
                original.point(at: 0.37 + 0.63 * parameter),
                accuracy: 1e-12
            )
        }

        let path = try XCTUnwrap(CurvePath2D.joining([
            .bezier(split.0),
            .bezier(split.1),
        ]))
        XCTAssertEqual(path.curves.count, 2)
        XCTAssertLessThan(
            abs(
                path.arcLength(tolerance: 1e-10)
                    - Curve2D.bezier(original).arcLength(tolerance: 1e-10)
            ),
            1e-9
        )
    }

    func testNURBSSplitPreservesTheArc() throws {
        let arc = makeArc(radius: 3, startAngle: 0.2, sweep: 2 * .pi / 3)
        guard case .nurbs(let nurbs) = arc else {
            XCTFail("expected a NURBS arc")
            return
        }
        let pieces = try XCTUnwrap(nurbs.split(at: 0.41))

        for parameter in [0.0, 0.1, 0.37, 0.75, 1.0] {
            assertClose(
                pieces.0.point(at: parameter),
                nurbs.point(at: 0.41 * parameter),
                accuracy: 1e-10
            )
            assertClose(
                pieces.1.point(at: parameter),
                nurbs.point(at: 0.41 + 0.59 * parameter),
                accuracy: 1e-10
            )
        }

        let leftLength = Curve2D.nurbs(pieces.0).arcLength(tolerance: 1e-10)
        let rightLength = Curve2D.nurbs(pieces.1).arcLength(tolerance: 1e-10)
        let wholeLength = arc.arcLength(tolerance: 1e-10)
        XCTAssertLessThan(abs(leftLength + rightLength - wholeLength), 1e-9)
    }

    func testNURBSWithAnInternalKnotSplits() throws {
        let nurbs = try XCTUnwrap(NURBSCurve2D(
            degree: 2,
            controlPoints: [
                Vec2(x: 0, y: 0),
                Vec2(x: 1, y: 2),
                Vec2(x: 2, y: 2),
                Vec2(x: 3, y: 0),
            ]
        ))
        XCTAssertEqual(nurbs.knots, [0, 0, 0, 0.5, 1, 1, 1])

        let pieces = try XCTUnwrap(nurbs.split(at: 0.62))
        for parameter in [0.0, 0.2, 0.6, 1.0] {
            assertClose(
                pieces.0.point(at: parameter),
                nurbs.point(at: 0.62 * parameter),
                accuracy: 1e-10
            )
            assertClose(
                pieces.1.point(at: parameter),
                nurbs.point(at: 0.62 + 0.38 * parameter),
                accuracy: 1e-10
            )
        }
        XCTAssertLessThan(
            abs(
                Curve2D.nurbs(pieces.0).arcLength(tolerance: 1e-10)
                    + Curve2D.nurbs(pieces.1).arcLength(tolerance: 1e-10)
                    - Curve2D.nurbs(nurbs).arcLength(tolerance: 1e-10)
            ),
            1e-9
        )
    }

    func testNURBSDerivativeMatchesFiniteDifference() {
        let arc = makeArc(radius: 2, startAngle: 0.1, sweep: .pi / 2)
        for parameter in [0.1, 0.3, 0.5, 0.7, 0.9] {
            let h = 1e-6
            let numeric = (arc.point(at: parameter + h) - arc.point(at: parameter - h))
                * (1 / (2 * h))
            assertClose(numeric, arc.derivative(at: parameter), accuracy: 1e-6)
        }
    }

    func testBezierDerivativeMatchesTheAnalyticDerivative() {
        guard let curve = Bezier2D([
            Vec2(x: 0, y: 0),
            Vec2(x: 1, y: 2),
            Vec2(x: 3, y: 2),
            Vec2(x: 4, y: 0),
        ]) else {
            XCTFail("the cubic failed the Bezier initializer")
            return
        }

        let first = Vec2(x: 1, y: 2) - Vec2(x: 0, y: 0)
        let second = Vec2(x: 3, y: 2) - Vec2(x: 1, y: 2)
        let third = Vec2(x: 4, y: 0) - Vec2(x: 3, y: 2)
        for parameter in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let t = parameter
            let oneMinus = 1 - t
            let expected = first * (3 * oneMinus * oneMinus)
                + second * (6 * oneMinus * t)
                + third * (3 * t * t)
            assertClose(curve.derivative(at: parameter), expected, accuracy: 1e-12)
        }
    }

    func testClosestPointOnOneThousandRandomCircleQueries() throws {
        let arcs = (0..<4).map { index in
            makeArc(
                radius: 2,
                startAngle: Double(index) * .pi / 2,
                sweep: .pi / 2
            )
        }
        let path = try XCTUnwrap(CurvePath2D.joining(arcs, tolerance: 1e-9))
        var random = CurveRandom(seed: 2026)
        var worstDistanceError = 0.0
        var worstPointError = 0.0

        for _ in 0..<1_000 {
            let angle = random.double(-.pi, .pi)
            let radius = random.double(0.2, 4.5)
            let query = Vec2(
                x: radius * cos(angle),
                y: radius * sin(angle)
            )
            let result = path.closestPoint(to: query)
            let expectedDistance = abs(radius - 2)
            let expectedPoint = Vec2(
                x: 2 * cos(angle),
                y: 2 * sin(angle)
            )
            worstDistanceError = max(
                worstDistanceError,
                abs(result.distance - expectedDistance)
            )
            worstPointError = max(
                worstPointError,
                result.point.distance(to: expectedPoint)
            )
        }

        XCTAssertLessThan(
            worstDistanceError,
            1e-7,
            "closest-point distance error \(worstDistanceError) exceeded 1e-7"
        )
        XCTAssertLessThan(
            worstPointError,
            1e-6,
            "closest-point location error \(worstPointError) exceeded 1e-6"
        )
    }

    func testClosestPointOnAStraightSegmentHasAnAnalyticAnswer() {
        guard let line = Bezier2D([
            Vec2(x: -3, y: 2),
            Vec2(x: 5, y: 2),
        ]) else {
            XCTFail("the line failed the Bezier initializer")
            return
        }
        let curve = Curve2D.bezier(line)
        var random = CurveRandom(seed: 99)
        for _ in 0..<100 {
            let query = Vec2(
                x: random.double(-2, 4),
                y: random.double(-3, 7)
            )
            let result = curve.closestPoint(to: query)
            XCTAssertLessThan(abs(result.distance - abs(query.y - 2)), 1e-9)
            XCTAssertLessThan(abs(result.point.x - query.x), 1e-7)
            XCTAssertLessThan(abs(result.point.y - 2), 1e-7)
        }
    }

    func testTwoDimensionalTransformsMapPointsAndRigidLength() {
        guard let curve = Bezier2D([
            Vec2(x: 0, y: 0),
            Vec2(x: 1, y: 2),
            Vec2(x: 3, y: 2),
            Vec2(x: 4, y: 0),
        ]) else {
            XCTFail("the cubic failed the Bezier initializer")
            return
        }
        let rigid = Mat3.translation2D(Vec2(x: 2, y: -1))
            * Mat3.rotation2D(0.37)
        let transformed = curve.transformed(by: rigid)
        for parameter in stride(from: 0.0, through: 1.0, by: 0.125) {
            assertClose(
                transformed.point(at: parameter),
                curve.point(at: parameter).transformed(by: rigid),
                accuracy: 1e-12
            )
        }
        XCTAssertLessThan(
            abs(
                Curve2D.bezier(transformed).arcLength(tolerance: 1e-10)
                    - Curve2D.bezier(curve).arcLength(tolerance: 1e-10)
            ),
            1e-9
        )

        let scaled = curve.transformed(by: Mat3.scale2D(x: 2, y: 2))
        XCTAssertLessThan(
            abs(
                Curve2D.bezier(scaled).arcLength(tolerance: 1e-10)
                    - 2 * Curve2D.bezier(curve).arcLength(tolerance: 1e-10)
            ),
            1e-9
        )
    }

    func testJoinRejectsAnEndpointGap() {
        guard
            let first = Bezier2D([Vec2(x: 0, y: 0), Vec2(x: 1, y: 0)]),
            let second = Bezier2D([Vec2(x: 1.1, y: 0), Vec2(x: 2, y: 0)])
        else {
            XCTFail("the test lines failed the Bezier initializer")
            return
        }
        XCTAssertNil(CurvePath2D.joining([.bezier(first), .bezier(second)]))
        XCTAssertNil(Curve2D.bezier(first).joined(to: .bezier(second)))
    }
}
