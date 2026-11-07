import XCTest
@testable import FacetForge

/// Phase 17's headless half: the click contract, the visibility rules, the
/// marquee window test and selection sets. The UI half lives in
/// `SelectionUITests`, because the row's acceptance is a UI test.
final class Phase17SelectionTests: XCTestCase {
    private let camera = FFCamera.standard
    private let viewport = Vec2(x: 800, y: 600)
    private let scene = FFViewportScene.jewelleryDemo

    func testClickReplacesExtendsAndClears() {
        var selection = FFSelectionState()
        let first = UUID()
        let second = UUID()

        selection.click(first)
        XCTAssertEqual(selection.selectedIDs, Set([first]))

        selection.click(second, extend: true)
        XCTAssertEqual(selection.selectedIDs, Set([first, second]))

        selection.click(first, extend: true)
        XCTAssertEqual(selection.selectedIDs, Set([second]))

        selection.click(nil)
        XCTAssertTrue(selection.selectedIDs.isEmpty)
    }

    func testMarqueeSelectsFullyContainedNodesOnly() throws {
        let stone = try XCTUnwrap(scene.nodes.first { $0.kind == .stone })
        let shank = try XCTUnwrap(scene.nodes.first { $0.kind == .solid })
        let stoneRect = try projectedBounds(of: stone)

        let stoneOnly = FFMarqueeSelection.nodeIDs(
            in: stoneRect.insetBy(dx: -4, dy: -4),
            scene: scene,
            camera: camera,
            viewport: viewport
        )
        XCTAssertEqual(stoneOnly, [stone.id], "a box around the stone must not drag the shank in")

        let everything = FFMarqueeSelection.nodeIDs(
            in: CGRect(x: 0, y: 0, width: 800, height: 600),
            scene: scene,
            camera: camera,
            viewport: viewport
        )
        XCTAssertEqual(Set(everything), Set([stone.id, shank.id]))
    }

    func testMarqueeHonoursKindFilterAndVisibility() throws {
        let stone = try XCTUnwrap(scene.nodes.first { $0.kind == .stone })
        let shank = try XCTUnwrap(scene.nodes.first { $0.kind == .solid })
        let all = CGRect(x: 0, y: 0, width: 800, height: 600)

        XCTAssertEqual(
            FFMarqueeSelection.nodeIDs(in: all, scene: scene, camera: camera, viewport: viewport, filter: .solid),
            [shank.id]
        )
        XCTAssertEqual(
            FFMarqueeSelection.nodeIDs(in: all, scene: scene, camera: camera, viewport: viewport, filter: .stone),
            [stone.id]
        )
        XCTAssertTrue(
            FFMarqueeSelection.nodeIDs(in: all, scene: scene, camera: camera, viewport: viewport, filter: .curve).isEmpty
        )

        let hidden = scene.selecting([]).nodes.map { node -> FFRenderNode in
            var copy = node
            copy.isVisible = node.id != shank.id
            return copy
        }
        XCTAssertEqual(
            FFMarqueeSelection.nodeIDs(
                in: all,
                scene: FFViewportScene(nodes: hidden),
                camera: camera,
                viewport: viewport
            ),
            [stone.id]
        )
    }

    func testIsolateAndHideChangeVisibilityThenShowAllRestores() throws {
        let stone = try XCTUnwrap(scene.nodes.first { $0.kind == .stone })
        let shank = try XCTUnwrap(scene.nodes.first { $0.kind == .solid })

        var selection = FFSelectionState(selectedIDs: [shank.id])
        selection.isolateSelection()
        var applied = selection.applying(to: scene)
        XCTAssertTrue(try XCTUnwrap(applied.node(id: shank.id)).isVisible)
        XCTAssertFalse(try XCTUnwrap(applied.node(id: stone.id)).isVisible)
        XCTAssertEqual(selection.visibilitySummary(in: scene), "1 hidden · isolated 1")

        selection.showAll()
        applied = selection.applying(to: scene)
        XCTAssertTrue(try XCTUnwrap(applied.node(id: stone.id)).isVisible)
        XCTAssertEqual(selection.visibilitySummary(in: scene), "0 hidden")

        selection = FFSelectionState(selectedIDs: [stone.id])
        selection.hideSelection()
        XCTAssertTrue(selection.selectedIDs.isEmpty)
        applied = selection.applying(to: scene)
        XCTAssertFalse(try XCTUnwrap(applied.node(id: stone.id)).isVisible)
        XCTAssertTrue(try XCTUnwrap(applied.node(id: shank.id)).isVisible)

        selection.showAll()
        XCTAssertTrue(try XCTUnwrap(selection.applying(to: scene).node(id: stone.id)).isVisible)
    }

    func testSelectionSetsRoundTrip() throws {
        let stone = try XCTUnwrap(scene.nodes.first { $0.kind == .stone })
        let shank = try XCTUnwrap(scene.nodes.first { $0.kind == .solid })

        var selection = FFSelectionState(selectedIDs: [stone.id, shank.id])
        selection.saveSelectionSet()
        XCTAssertEqual(selection.sets.count, 1)
        XCTAssertEqual(selection.sets[0].name, "Set 1")
        XCTAssertEqual(Set(selection.sets[0].nodeIDs), Set([stone.id, shank.id]))

        selection.clearSelection()
        XCTAssertEqual(selection.summary(in: scene), "No selection")

        selection.apply(selection.sets[0])
        XCTAssertEqual(selection.selectedIDs, Set([stone.id, shank.id]))
        XCTAssertEqual(selection.summary(in: scene), "2 selected")
    }

    func testSceneApplicationMarksExactlyTheSelectedNodes() throws {
        let stone = try XCTUnwrap(scene.nodes.first { $0.kind == .stone })
        let shank = try XCTUnwrap(scene.nodes.first { $0.kind == .solid })

        let selection = FFSelectionState(selectedIDs: [shank.id])
        let applied = selection.applying(to: scene)
        XCTAssertEqual(applied.selectedNodeIDs, [shank.id])
        XCTAssertFalse(try XCTUnwrap(applied.node(id: stone.id)).isSelected)
        XCTAssertTrue(try XCTUnwrap(applied.node(id: shank.id)).isSelected)
        XCTAssertEqual(selection.summary(in: scene), "Shank")
    }

    private func projectedBounds(of node: FFRenderNode) throws -> CGRect {
        let points = try node.mesh.positions.map { position -> CGPoint in
            let world = node.transform * Vec4(x: position.x, y: position.y, z: position.z, w: 1)
            let screen = try XCTUnwrap(camera.screenPoint(
                for: Vec3(x: world.x, y: world.y, z: world.z),
                viewport: viewport
            ))
            return CGPoint(x: screen.x, y: screen.y)
        }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minimumX = try XCTUnwrap(xs.min())
        let maximumX = try XCTUnwrap(xs.max())
        let minimumY = try XCTUnwrap(ys.min())
        let maximumY = try XCTUnwrap(ys.max())
        return CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }
}
