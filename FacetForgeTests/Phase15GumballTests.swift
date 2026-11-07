import CoreGraphics
import XCTest
@testable import FacetForge

/// Phase 15 proves the gizmo maths rather than the drawing: a drag is
/// projected through the same camera, snapped once, and committed as one undo
/// step. Plane constraints may not leak into the third axis, and a pivot edit
/// changes the gizmo without moving geometry.
final class Phase15GumballTests: XCTestCase {
    private let viewport = Vec2(x: 400, y: 400)

    func testMoveAlongXSnapsToTenMillimetresAndOneUndoRestores() {
        var session = FFGumballSession()
        session.select(
            nodeID: UUID(),
            transform: Mat4.translation(Vec3(x: 0, y: 40, z: 0))
        )
        session.snapStep = 1

        session.beginDrag()
        session.move(by: Vec3(x: 9.6, y: 0, z: 0))
        session.commitDrag()

        XCTAssertEqual(session.transform.m03, 10, accuracy: 1e-9)
        XCTAssertEqual(session.transform.m13, 40, accuracy: 1e-9)
        XCTAssertEqual(session.undoStack.count, 1)
        XCTAssertTrue(session.canUndo)

        XCTAssertTrue(session.undo())
        XCTAssertEqual(session.transform.m03, 0, accuracy: 1e-9)
        XCTAssertEqual(session.transform.m13, 40, accuracy: 1e-9)
        XCTAssertFalse(session.canUndo)
    }

    func testAxisConstraintKeepsTheOtherTwoAxesAtZero() {
        let delta = FFGumballMath.moveDelta(
            constraint: .axis(.x),
            screenTranslation: CGSize(width: 120, height: 80),
            camera: .standard,
            pivot: .zero,
            viewport: viewport,
            snap: 1
        )
        guard let moved = delta else { return XCTFail("axis produced no delta") }
        XCTAssertEqual(moved.y, 0, accuracy: 1e-12)
        XCTAssertEqual(moved.z, 0, accuracy: 1e-12)
        XCTAssertNotEqual(moved.x, 0)
    }

    func testPlaneConstraintNeverMovesTheThirdAxis() {
        guard let xScale = FFGumballMath.axisScreenScale(
            axis: .x,
            pivot: .zero,
            camera: .standard,
            viewport: viewport
        ) else {
            return XCTFail("X axis does not project")
        }
        let drag = xScale.unit * (3.2 / xScale.millimetresPerPoint)
        guard let delta = FFGumballMath.moveDelta(
            constraint: .plane(.x, .y),
            screenTranslation: CGSize(width: drag.x, height: drag.y),
            camera: .standard,
            pivot: .zero,
            viewport: viewport,
            snap: 1
        ) else {
            return XCTFail("plane produced no delta")
        }
        XCTAssertEqual(delta.z, 0, accuracy: 1e-9)
        XCTAssertEqual(delta.x, 3, accuracy: 1e-9)
    }

    func testRotationTurnsAroundThePivotNotTheOrigin() {
        var session = FFGumballSession()
        session.select(
            nodeID: UUID(),
            transform: Mat4.translation(Vec3(x: 0, y: 40, z: 0))
        )
        session.beginDrag()
        session.rotate(around: .y, degrees: 90)
        session.commitDrag()

        let point = session.transform * Vec4(x: 1, y: 0, z: 0, w: 1)
        XCTAssertEqual(point.x, 0, accuracy: 1e-9)
        XCTAssertEqual(point.y, 40, accuracy: 1e-9)
        XCTAssertEqual(point.z, -1, accuracy: 1e-9)
        XCTAssertEqual(session.pivot.y, 40, accuracy: 1e-9)
    }

    func testScaleIsAnchoredAtThePivot() {
        var session = FFGumballSession()
        session.select(nodeID: UUID(), transform: .identity)
        session.beginDrag()
        session.scale(around: .x, factor: 2)
        session.commitDrag()

        let point = session.transform * Vec4(x: 1, y: 0, z: 0, w: 1)
        XCTAssertEqual(point.x, 2, accuracy: 1e-9)
        XCTAssertEqual(point.y, 0, accuracy: 1e-9)
        XCTAssertEqual(point.z, 0, accuracy: 1e-9)
    }

    func testNumericEntryIsAbsoluteAndUndoable() {
        var session = FFGumballSession()
        session.select(
            nodeID: UUID(),
            transform: Mat4.translation(Vec3(x: 0, y: 40, z: 0))
        )
        session.setTranslation(x: 12.5)
        XCTAssertEqual(session.transform.m03, 12.5, accuracy: 1e-9)
        session.setTranslation(y: 41)
        XCTAssertEqual(session.transform.m13, 41, accuracy: 1e-9)

        XCTAssertTrue(session.undo())
        XCTAssertEqual(session.transform.m13, 40, accuracy: 1e-9)
        XCTAssertEqual(session.transform.m03, 12.5, accuracy: 1e-9)
    }

    func testPivotEditMovesTheGizmoButNotTheGeometry() {
        var session = FFGumballSession()
        session.select(nodeID: UUID(), transform: .identity)
        session.setPivot(Vec3(x: 5, y: 5, z: 5))

        XCTAssertEqual(session.pivot, Vec3(x: 5, y: 5, z: 5))
        XCTAssertEqual(session.transform, .identity)

        session.beginDrag()
        session.move(by: Vec3(x: 2, y: 0, z: 0))
        session.commitDrag()

        XCTAssertEqual(session.transform.m03, 2, accuracy: 1e-9)
        XCTAssertEqual(session.pivot.x, 7, accuracy: 1e-9)
    }

    func testSnapCyclesThroughTheDocumentedSteps() {
        var session = FFGumballSession()
        XCTAssertEqual(session.snapStep, 1)
        session.cycleSnap()
        XCTAssertEqual(session.snapStep, 5)
        session.cycleSnap()
        XCTAssertEqual(session.snapStep, 0.1, accuracy: 1e-9)
        session.cycleSnap()
        XCTAssertEqual(session.snapStep, 1)
    }
}
