import XCTest
@testable import FacetForge

/// Phase 23's edit integration: both pane-local interactions commit through
/// `FFDocumentSession.perform`, a drag or measurement is one history entry, one
/// undo reverts exactly that edit, and save/reopen keeps the committed
/// transform and the measurement annotation.
final class Phase23EditIntegrationTests: XCTestCase {
    private func stoneID(in session: FFEditorSession) throws -> UUID {
        try XCTUnwrap(session.selection.selectedIDs.first, "the bench sample should select its stone")
    }

    private func translated(_ base: Mat4, x: Double) -> Mat4 {
        Mat4.translation(Vec3(x: x, y: 0, z: 0)) * base
    }

    /// A frame-by-frame drag is many mutations with one gesture key. The
    /// document must end with one undo step, not one per frame.
    func testFrameByFrameDragIsOneCoalescedHistoryEntryAndOneUndoRevertsIt() throws {
        let session = FFEditorSession()
        let nodeID = try stoneID(in: session)
        let base = try XCTUnwrap(session.document.node(withID: nodeID)).transform.matrix
        let historyBefore = session.documentSession.undoDepth
        let dragKey = "drag-\(UUID().uuidString)"

        for frame in 1...30 {
            XCTAssertTrue(
                session.commitGizmoTransform(
                    nodeID: nodeID,
                    worldTransform: translated(base, x: Double(frame) / 3),
                    dragKey: dragKey
                ),
                "frame \(frame) did not commit"
            )
        }

        XCTAssertEqual(
            session.documentSession.undoDepth,
            historyBefore + 1,
            "30 frames of one drag must coalesce into one history entry"
        )
        let committed = try XCTUnwrap(session.document.node(withID: nodeID))
        XCTAssertEqual(committed.transform.translation.x, 10, accuracy: 1e-9)
        XCTAssertEqual(committed.transform.translation.y, 40, accuracy: 1e-9)

        XCTAssertTrue(session.undo())
        let restored = try XCTUnwrap(session.document.node(withID: nodeID))
        XCTAssertEqual(restored.transform.translation.x, 0, accuracy: 1e-9)
        XCTAssertEqual(restored.transform.translation.y, 40, accuracy: 1e-9)
        XCTAssertEqual(session.documentSession.undoDepth, historyBefore)
    }

    func testTwoSeparateDragsStayTwoHistoryEntries() throws {
        let session = FFEditorSession()
        let nodeID = try stoneID(in: session)
        let base = try XCTUnwrap(session.document.node(withID: nodeID)).transform.matrix
        let historyBefore = session.documentSession.undoDepth

        XCTAssertTrue(
            session.commitGizmoTransform(
                nodeID: nodeID,
                worldTransform: translated(base, x: 10),
                dragKey: "drag-a"
            )
        )
        XCTAssertTrue(
            session.commitGizmoTransform(
                nodeID: nodeID,
                worldTransform: translated(base, x: 20),
                dragKey: "drag-b"
            )
        )

        XCTAssertEqual(session.documentSession.undoDepth, historyBefore + 2)
        XCTAssertEqual(session.documentSession.undoName, "Transform Stone")
    }

    func testMeasurementCommitsOneEntryAndUndoRemovesOnlyIt() throws {
        let session = FFEditorSession()
        let nodeID = try stoneID(in: session)
        let base = try XCTUnwrap(session.document.node(withID: nodeID)).transform.matrix
        XCTAssertTrue(
            session.commitGizmoTransform(
                nodeID: nodeID,
                worldTransform: translated(base, x: 10),
                dragKey: "drag-before-measurement"
            )
        )

        let measurement = FFMeasurement(
            kind: .distance,
            points: [
                FFMeasurementPoint(position: Vec3(x: 0, y: 0, z: 0), snap: .vertex),
                FFMeasurementPoint(position: Vec3(x: 3, y: 4, z: 0), snap: .midpoint)
            ]
        )
        XCTAssertTrue(session.addMeasurement(measurement))
        XCTAssertEqual(session.documentSession.undoDepth, 2)
        XCTAssertEqual(session.measurements.count, 1)
        XCTAssertEqual(try XCTUnwrap(session.measurements.first?.value), 5, accuracy: 1e-12)
        XCTAssertEqual(
            session.document.measurements.first?.snaps.compactMap { $0 },
            ["vertex", "midpoint"]
        )

        XCTAssertTrue(session.undo())
        XCTAssertTrue(session.measurements.isEmpty, "one undo must remove the measurement")
        XCTAssertTrue(session.document.measurements.isEmpty)
        let stillMoved = try XCTUnwrap(session.document.node(withID: nodeID))
        XCTAssertEqual(
            stillMoved.transform.translation.x,
            10,
            accuracy: 1e-9,
            "undoing the measurement must not undo the earlier drag"
        )

        XCTAssertTrue(session.undo())
        let restored = try XCTUnwrap(session.document.node(withID: nodeID))
        XCTAssertEqual(restored.transform.translation.x, 0, accuracy: 1e-9)
    }

    /// The measured points come from the Phase 16 snap resolver, not from
    /// hand-written coordinates, so this is the row's snapped-measurement path
    /// with a real document history entry.
    func testSnappedMeasurementCommitsOneEntry() throws {
        let mesh = FFRenderMesh(
            positions: [
                Vec3(x: 0, y: 0, z: 0),
                Vec3(x: 10, y: 0, z: 0),
                Vec3(x: 0, y: 0, z: 10)
            ],
            normals: [
                Vec3(x: 0, y: 1, z: 0),
                Vec3(x: 0, y: 1, z: 0),
                Vec3(x: 0, y: 1, z: 0)
            ],
            indices: [0, 1, 2]
        )
        let node = FFRenderNode(name: "Fixture", mesh: mesh)
        let scene = FFViewportScene(nodes: [node])
        let session = FFEditorSession()
        let camera = FFCamera(
            target: Vec3(x: 3, y: 0, z: 3),
            distance: 40,
            projection: .orthographic
        )
        let viewport = Vec2(x: 800, y: 600)

        func snapped(_ world: Vec3) throws -> FFMeasurementPoint {
            let screen = try XCTUnwrap(camera.screenPoint(for: world, viewport: viewport))
            return try XCTUnwrap(FFMeasurementSnap.point(
                at: screen,
                scene: scene,
                camera: camera,
                viewport: viewport
            ))
        }

        let first = try snapped(Vec3(x: 10, y: 0, z: 0))
        let second = try snapped(Vec3(x: 0, y: 0, z: 10))
        XCTAssertEqual(first.snap, .vertex)
        XCTAssertEqual(second.snap, .vertex)
        let measurement = FFMeasurement(kind: .distance, points: [first, second])
        XCTAssertTrue(session.addMeasurement(measurement))
        XCTAssertEqual(session.documentSession.undoDepth, 1)
        XCTAssertEqual(session.measurements.count, 1)
        XCTAssertEqual(try XCTUnwrap(session.measurements.first?.value), sqrt(200), accuracy: 1e-9)

        XCTAssertTrue(session.undo())
        XCTAssertTrue(session.measurements.isEmpty)
        XCTAssertEqual(session.documentSession.undoDepth, 0)
    }

    func testSaveAndReopenPreserveTheCommittedTransformAndAnnotation() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("phase23-\(UUID().uuidString).facetforge.json")
        defer { try? FileManager.default.removeItem(at: url) }

        let session = FFEditorSession()
        let nodeID = try stoneID(in: session)
        let base = try XCTUnwrap(session.document.node(withID: nodeID)).transform.matrix
        XCTAssertTrue(
            session.commitGizmoTransform(
                nodeID: nodeID,
                worldTransform: translated(base, x: 10),
                dragKey: "drag-to-save"
            )
        )
        let measurement = FFMeasurement(
            kind: .diameter,
            points: [
                FFMeasurementPoint(position: Vec3(x: -9, y: 0, z: 0), snap: .vertex),
                FFMeasurementPoint(position: Vec3(x: 9, y: 0, z: 0), snap: .vertex),
                FFMeasurementPoint(position: Vec3(x: 0, y: 9, z: 0), snap: .midpoint)
            ]
        )
        XCTAssertTrue(session.addMeasurement(measurement))
        try session.save(to: url)

        // Discard the in-memory document before reopening, so a passing
        // assertion cannot be the old document still on screen.
        session.newDocument()
        XCTAssertTrue(session.measurements.isEmpty)
        try session.reopen(from: url)

        let reopened = try XCTUnwrap(session.document.node(withID: nodeID))
        XCTAssertEqual(reopened.transform.translation.x, 10, accuracy: 1e-9)
        XCTAssertEqual(reopened.transform.translation.y, 40, accuracy: 1e-9)
        XCTAssertEqual(session.measurements.count, 1)
        let annotation = try XCTUnwrap(session.measurements.first)
        XCTAssertEqual(annotation.id, measurement.id)
        XCTAssertEqual(annotation.kind, .diameter)
        XCTAssertEqual(
            annotation.points.map(\.snap),
            [FFSnapKind?.some(.vertex), .some(.vertex), .some(.midpoint)]
        )
        XCTAssertEqual(try XCTUnwrap(annotation.value), 18, accuracy: 1e-9)
        XCTAssertEqual(session.documentSession.undoDepth, 0, "reopen resets the undo history")
    }

    func testLegacyDocumentWithoutMeasurementsStillDecodes() throws {
        let legacy = """
        {
          "schemaVersion": 1,
          "name": "Legacy",
          "materials": [],
          "rootNodes": []
        }
        """.data(using: .utf8)!

        let document = try FFDocument.decoded(from: legacy)
        XCTAssertTrue(document.measurements.isEmpty)
    }
}
