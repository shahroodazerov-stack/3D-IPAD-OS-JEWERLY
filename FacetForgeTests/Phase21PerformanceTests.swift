import Metal
import XCTest
@testable import FacetForge

/// Phase 21: the performance HUD must show numbers that actually describe the
/// frame that reached Metal. These tests cross-check the overlay's counters
/// against an independently derived pass count for a known scene, rather than
/// trusting the counter it reads.
final class Phase21PerformanceTests: XCTestCase {
    func testCountersMatchThePassesEncodedForKnownScenes() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is unavailable on this host")
        }
        let renderer = try FFMetalViewportRenderer()

        let left = try renderNode(name: "Left", x: -20)
        let right = try renderNode(name: "Right", x: 20)
        let scene = FFViewportScene(nodes: [left, right])
        let bounds = try XCTUnwrap(scene.bounds)
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.25)

        // Shaded: shadow quad (1 draw, 2 triangles) + grid lines (1, 0) +
        // two octahedra with 8 triangles each (2 draws, 16).
        XCTAssertNotNil(renderer.renderOffscreen(width: 240, height: 180, camera: camera, scene: scene))
        XCTAssertEqual(renderer.lastCounters.drawCalls, 4)
        XCTAssertEqual(renderer.lastCounters.triangles, 18)

        // Wireframe: no shadow, no grid, two edge draws, no triangles.
        XCTAssertNotNil(
            renderer.renderOffscreen(width: 240, height: 180, camera: camera, scene: scene, mode: .wireframe)
        )
        XCTAssertEqual(renderer.lastCounters.drawCalls, 2)
        XCTAssertEqual(renderer.lastCounters.triangles, 0)

        // Selected shaded: the selection outline adds one draw of the selected
        // mesh's 8 triangles on top of the shaded passes.
        let selected = scene.selecting([left.id])
        XCTAssertNotNil(renderer.renderOffscreen(width: 240, height: 180, camera: camera, scene: selected))
        XCTAssertEqual(renderer.lastCounters.drawCalls, 5)
        XCTAssertEqual(renderer.lastCounters.triangles, 26)

        // An empty scene has no shadow (no bounds) and no meshes: only the grid.
        XCTAssertNotNil(
            renderer.renderOffscreen(width: 96, height: 72, camera: .standard, scene: .empty)
        )
        XCTAssertEqual(renderer.lastCounters.drawCalls, 1)
        XCTAssertEqual(renderer.lastCounters.triangles, 0)
    }

    func testFrameStatisticsReportsTheLastFrameAndAOneSecondAverage() {
        var statistics = FFFrameStatistics()
        statistics.record(frameAt: 10)
        XCTAssertEqual(statistics.lastFrameMilliseconds, 0)

        statistics.record(frameAt: 10.016)
        XCTAssertEqual(statistics.lastFrameMilliseconds, 16, accuracy: 0.001)

        // A repeat of the same timestamp is not a new frame.
        statistics.record(frameAt: 10.016)
        XCTAssertEqual(statistics.lastFrameMilliseconds, 16, accuracy: 0.001)
        XCTAssertEqual(statistics.frameCount, 2)

        statistics.record(frameAt: 10.5)
        XCTAssertEqual(statistics.lastFrameMilliseconds, 484, accuracy: 0.001)
        XCTAssertEqual(statistics.averageFPS, 0, "A 0.5 s window is not yet a one-second average")

        statistics.record(frameAt: 11.0)
        XCTAssertEqual(statistics.averageFPS, 3, accuracy: 0.001)
        XCTAssertEqual(statistics.frameCount, 4)
        XCTAssertEqual(statistics.lastFrameMilliseconds, 500, accuracy: 0.001)
    }

    func testReportLabelsReadAtBenchScale() {
        var report = FFPerformanceReport()
        report.fps = 59.94
        report.frameMilliseconds = 16.666
        report.drawCalls = 7
        report.triangles = 1_204
        report.availableMemoryBytes = 1_610_612_736
        report.thermalState = .fair

        XCTAssertEqual(report.fpsLabel, "60 fps")
        XCTAssertEqual(report.frameLabel, "16.7 ms")
        XCTAssertEqual(report.memoryLabel, "1.5 GB")
        XCTAssertEqual(report.thermalLabel, "Fair")
        XCTAssertEqual(
            report.accessibilitySummary,
            "Performance overlay, FPS 60 fps, frame 16.7 ms, draw calls 7, 1204 triangles, memory 1.5 GB, thermal Fair"
        )

        report.fps = 0
        XCTAssertEqual(report.fpsLabel, "starting")

        report.availableMemoryBytes = 536_870_912
        XCTAssertEqual(report.memoryLabel, "512 MB")

        report.thermalState = .critical
        XCTAssertEqual(report.thermalLabel, "Critical")
    }

    func testLiveReportCarriesTheOSFiguresAndTheLastEncodedCounters() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is unavailable on this host")
        }
        let renderer = try FFMetalViewportRenderer()
        let node = try renderNode(name: "Solo", x: 0)
        let scene = FFViewportScene(nodes: [node])
        let bounds = try XCTUnwrap(scene.bounds)
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.25)
        XCTAssertNotNil(renderer.renderOffscreen(width: 120, height: 90, camera: camera, scene: scene))

        var statistics = FFFrameStatistics()
        statistics.record(frameAt: 0)
        statistics.record(frameAt: 0.5)
        statistics.record(frameAt: 1.0)
        var counters = FFRenderCounters()
        counters.recordTriangles(8)
        counters.recordLines()

        let report = FFPerformanceReport.current(statistics: statistics, counters: counters)
        XCTAssertEqual(report.fps, 2, accuracy: 0.001)
        XCTAssertEqual(report.frameMilliseconds, 500, accuracy: 0.001)
        XCTAssertEqual(report.drawCalls, 2)
        XCTAssertEqual(report.triangles, 8)
        XCTAssertGreaterThan(report.availableMemoryBytes, 0)
        XCTAssertEqual(report.thermalState, ProcessInfo.processInfo.thermalState)

        // The renderer's own report must carry the pass it just encoded, not
        // only the statistics window.
        let live = renderer.performanceReport
        XCTAssertEqual(live.drawCalls, renderer.lastCounters.drawCalls)
        XCTAssertEqual(live.triangles, renderer.lastCounters.triangles)
        XCTAssertGreaterThan(live.drawCalls, 0)
        XCTAssertGreaterThan(live.availableMemoryBytes, 0)
        let knownStates: [ProcessInfo.ThermalState] = [.nominal, .fair, .serious, .critical]
        XCTAssertTrue(
            knownStates.contains(report.thermalState),
            "Thermal state must be one of the four ProcessInfo cases"
        )
    }

    private func renderNode(name: String, x: Double) throws -> FFRenderNode {
        let mesh = try XCTUnwrap(FFMeshFactory.octahedron(radius: 14))
        let renderMesh = try XCTUnwrap(FFRenderMesh(mesh: mesh))
        return FFRenderNode(
            name: name,
            mesh: renderMesh,
            transform: Mat4.translation(Vec3(x: x, y: 0, z: 0)),
            material: .gold
        )
    }
}
