import Foundation
import XCTest
@testable import FacetForge

final class TessellationTests: XCTestCase {
    private func quality(
        chordal: Double = 0.005,
        angularDegrees: Double = 90,
        maximumSegments: Int = 4_096
    ) -> TessellationSettings {
        guard let settings = TessellationSettings(
            chordalTolerance: chordal,
            angularTolerance: FFMath.radians(angularDegrees),
            maximumSegments: maximumSegments
        ) else {
            fatalError("test tessellation settings must be valid")
        }
        return settings
    }

    private func distanceToSegment(_ point: Vec2, _ start: Vec2, _ end: Vec2) -> Double {
        let edge = end - start
        let denominator = edge.lengthSquared
        guard denominator > 1e-24 else { return point.distance(to: start) }
        let t = FFMath.clamp((point - start).dot(edge) / denominator, to: 0...1)
        return point.distance(to: start + edge * t)
    }

    private func sCurve() -> Curve2D {
        guard let bezier = Bezier2D([
            Vec2(x: 0, y: 0),
            Vec2(x: 10, y: 25),
            Vec2(x: 30, y: -25),
            Vec2(x: 40, y: 0),
        ]) else {
            fatalError("test curve must be valid")
        }
        return .bezier(bezier)
    }

    func testTwentyMillimetreCircleAtFiveMicronsUsesExactlyOneHundredSegments() {
        let settings = quality()
        guard let circle = Tessellator.tessellateCircle(radius: 10, settings: settings) else {
            return XCTFail("a valid circle must tessellate")
        }

        let formula = Int(ceil(.pi / acos(1 - 0.005 / 10)))
        XCTAssertEqual(formula, 100)
        XCTAssertEqual(circle.segmentCount, formula)
        XCTAssertEqual(circle.points.count, 100)
        XCTAssertTrue(circle.isClosed)
        XCTAssertTrue(circle.toleranceMet)
        XCTAssertEqual(circle.triangleCount, 98)
        XCTAssertEqual(circle.length, 2 * .pi * 10, accuracy: 0.01)
    }

    func testTwentySampledArcMidpointsStayInsideFiveMicrons() {
        let settings = quality()
        guard let circle = Tessellator.tessellateCircle(radius: 10, settings: settings) else {
            return XCTFail("a valid circle must tessellate")
        }
        XCTAssertEqual(circle.segmentCount, 100)

        let step = (2 * .pi) / Double(circle.segmentCount)
        let expectedEdge = 2 * 10 * sin(step / 2)
        for index in 0..<circle.segmentCount {
            let start = circle.points[index]
            let end = circle.points[(index + 1) % circle.points.count]
            XCTAssertEqual(start.distance(to: end), expectedEdge, accuracy: 1e-12)
        }

        for sample in 0..<20 {
            let segment = sample * 5
            let angle = (Double(segment) + 0.5) * step
            let midpoint = Vec2(x: 10 * cos(angle), y: 10 * sin(angle))
            let deviation = distanceToSegment(
                midpoint,
                circle.points[segment],
                circle.points[(segment + 1) % circle.points.count]
            )
            XCTAssertLessThan(deviation, 0.005)
        }

        XCTAssertEqual(Tessellator.circleDeviation(radius: 10, segments: 100)!, 0.004934, accuracy: 1e-6)
    }

    func testAngularToleranceCanRequestMoreSegmentsThanTheChordalTerm() {
        let settings = quality(chordal: 1, angularDegrees: 1)
        guard let circle = Tessellator.tessellateCircle(radius: 10, settings: settings) else {
            return XCTFail("a valid circle must tessellate")
        }

        XCTAssertEqual(circle.segmentCount, 360)
        XCTAssertTrue(circle.toleranceMet)
        XCTAssertLessThan(circle.triangleCount, circle.segmentCount)
    }

    func testDisplayAndExportLODAreOrderedAndBothMeetTheirOwnTolerance() {
        guard
            let display = Tessellator.tessellateCircle(radius: 10, settings: .display),
            let export = Tessellator.tessellateCircle(radius: 10, settings: .export)
        else {
            return XCTFail("both built-in presets must tessellate a valid circle")
        }

        XCTAssertEqual(TessellationLOD.allCases, [.display, .export])
        XCTAssertLessThan(TessellationSettings.display.chordalTolerance, TessellationSettings.export.chordalTolerance)
        XCTAssertLessThan(display.segmentCount, export.segmentCount)
        XCTAssertGreaterThanOrEqual(export.segmentCount, 100)
        XCTAssertTrue(display.toleranceMet)
        XCTAssertTrue(export.toleranceMet)
    }

    func testTriangleBudgetCapsTheCircleAndReportsTheTradeoff() {
        var manager = TriangleBudgetManager(maximumTriangles: 100)
        XCTAssertEqual(manager.reserve(60), 60)
        XCTAssertEqual(manager.reserve(60), 40)
        XCTAssertEqual(manager.reserve(1), 0)
        XCTAssertTrue(manager.isExhausted)
        manager.reset()
        XCTAssertEqual(manager.remainingTriangles, 100)

        var budget = TriangleBudgetManager(maximumTriangles: 50)
        guard let circle = Tessellator.tessellateCircle(
            radius: 10,
            settings: .export,
            budget: &budget
        ) else {
            return XCTFail("a 50-triangle budget can afford a circle")
        }
        XCTAssertEqual(circle.segmentCount, 52)
        XCTAssertEqual(circle.triangleCount, 50)
        XCTAssertEqual(budget.usedTriangles, 50)
        XCTAssertTrue(budget.isExhausted)
        XCTAssertFalse(circle.toleranceMet)

        var empty = TriangleBudgetManager(maximumTriangles: 0)
        XCTAssertNil(Tessellator.tessellateCircle(radius: 10, settings: .export, budget: &empty))
        XCTAssertEqual(empty.usedTriangles, 0)
    }

    func testAdaptiveBezierTessellationMeetsItsChordalTolerance() {
        let curve = sCurve()
        let settings = quality(chordal: 0.05, angularDegrees: 5, maximumSegments: 512)
        guard let path = Tessellator.tessellate(curve, settings: settings) else {
            return XCTFail("a valid Bézier must tessellate")
        }

        XCTAssertTrue(path.toleranceMet)
        XCTAssertGreaterThan(path.segmentCount, 8)
        XCTAssertLessThanOrEqual(path.segmentCount, 512)
        let measured = path.maximumDeviation(of: curve, samples: 600)
        XCTAssertLessThan(measured, 0.05)
    }

    func testMaximumSegmentCapIsHonouredAndReportedAsUnmetTolerance() {
        let curve = sCurve()
        let settings = quality(chordal: 1e-9, angularDegrees: 0.001, maximumSegments: 8)
        guard let path = Tessellator.tessellate(curve, settings: settings) else {
            return XCTFail("the curve must still produce the capped path")
        }

        XCTAssertLessThanOrEqual(path.segmentCount, 8)
        XCTAssertGreaterThanOrEqual(path.segmentCount, 3)
        XCTAssertFalse(path.toleranceMet)
    }

    func testClosedCurveDropsTheDuplicateEndpointAndInvalidInputsAreRejected() {
        guard
            let bezier = Bezier2D([
                Vec2(x: 0, y: 0),
                Vec2(x: 10, y: 0),
                Vec2(x: 10, y: 10),
                Vec2(x: 0, y: 10),
                Vec2(x: 0, y: 0),
            ])
        else {
            return XCTFail("closed test curve must be valid")
        }

        let settings = quality(chordal: 0.01, angularDegrees: 5, maximumSegments: 512)
        guard let closed = Tessellator.tessellate(.bezier(bezier), settings: settings) else {
            return XCTFail("closed curve must tessellate")
        }
        XCTAssertTrue(closed.isClosed)
        XCTAssertEqual(closed.points.count, closed.segmentCount)
        XCTAssertGreaterThanOrEqual(closed.segmentCount, 3)
        XCTAssertGreaterThan(closed.length, 0)
        XCTAssertTrue(closed.toleranceMet)

        XCTAssertNil(TessellationSettings(
            chordalTolerance: 0,
            angularTolerance: .pi / 4,
            maximumSegments: 100
        ))
        XCTAssertNil(TessellationSettings(
            chordalTolerance: 0.01,
            angularTolerance: 0,
            maximumSegments: 100
        ))
        XCTAssertNil(TessellationSettings(
            chordalTolerance: 0.01,
            angularTolerance: .pi / 4,
            maximumSegments: 2
        ))
        XCTAssertNil(Tessellator.tessellateCircle(radius: 0, settings: .display))
        XCTAssertNil(Tessellator.circleSegmentCount(radius: -1, settings: .display))
        XCTAssertNil(Tessellator.circleDeviation(radius: 10, segments: 2))
    }
}
