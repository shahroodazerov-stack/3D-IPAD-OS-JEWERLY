import Metal
import QuartzCore
import UIKit
import XCTest
@testable import FacetForge

/// Phase 13 proves four things a compilation cannot: the deliberate layout is
/// frozen, a 100k-triangle kernel mesh reaches shaded pixels, selection draws an
/// outline rather than a recolour, and the RealityKit bridge accepts the same
/// scene the Metal viewport draws.
final class Phase13ViewportTests: XCTestCase {
    func testDefaultLayoutIsSingleMaximisedPerspective() {
        XCTAssertEqual(FFViewportLayout.defaultLayout, .single)

        let panes = FFViewportLayout.defaultLayout.panes
        XCTAssertEqual(panes.count, 1)
        guard let pane = panes.first else { return XCTFail("single layout has no pane") }
        XCTAssertEqual(pane.title, "Perspective")
        XCTAssertEqual(pane.projection, .perspective)
        XCTAssertEqual(pane.namedView, .iso)
        XCTAssertEqual(pane.accessibilityIdentifier, "shell.viewport.pane.perspective")
    }

    func testFourUpPresetHasFourNamedPanesAndReturnsToSingle() {
        let fourUp = FFViewportLayout.fourUp
        XCTAssertEqual(fourUp.panes.count, 4)
        XCTAssertEqual(fourUp.panes.map(\.id), ["perspective", "top", "front", "right"])
        XCTAssertEqual(fourUp.panes.map(\.title), ["Perspective", "Top", "Front", "Right"])
        XCTAssertEqual(fourUp.panes.map(\.projection), [.perspective, .orthographic, .orthographic, .orthographic])
        XCTAssertEqual(fourUp.panes[0].namedView, .iso)
        XCTAssertEqual(fourUp.panes[1].namedView, .top)
        XCTAssertEqual(fourUp.panes[2].namedView, .front)
        XCTAssertEqual(fourUp.panes[3].namedView, .right)
        XCTAssertEqual(fourUp.initialCameras.count, 4)

        // The preset is a value, not a mode mutation: selecting single again
        // still exposes exactly one maximised Perspective pane.
        XCTAssertEqual(FFViewportLayout.single.panes.count, 1)
        XCTAssertEqual(FFViewportLayout.single.panes.first?.projection, .perspective)
    }

    func testHundredThousandTriangleMeshRendersWithShading() throws {
        let renderer = try makeRenderer()
        guard let mesh = FFMeshFactory.torus(
            majorRadius: 30,
            minorRadius: 4.5,
            majorSegments: 320,
            minorSegments: 180
        ), let renderMesh = FFRenderMesh(mesh: mesh) else {
            return XCTFail("could not build the 100k-triangle fixture")
        }
        XCTAssertGreaterThan(renderMesh.triangleCount, 100_000)

        let scene = FFViewportScene(nodes: [
            FFRenderNode(name: "Phase 13 large shank", mesh: renderMesh, material: .gold),
        ])
        guard let bounds = scene.bounds else { return XCTFail("large scene has no bounds") }
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.2)

        guard let image = renderer.render(
            scene: scene,
            camera: camera,
            width: 320,
            height: 240
        ) else {
            return XCTFail("100k-triangle render produced no readback")
        }
        attach(image, name: "phase13-100k-shaded")

        let counts = classify(image)
        XCTAssertGreaterThan(counts.lit, 3_000, "the 100k mesh produced almost no shaded pixels")
        XCTAssertGreaterThan(counts.gold, 500, "the gold material did not shade the large mesh")
        XCTAssertNil(renderer.lastCommandBufferError)
    }

    func testSelectionOutlineAddsMagentaPixelsOnlyWhenSelected() throws {
        let renderer = try makeRenderer()
        guard let mesh = FFMeshFactory.octahedron(radius: 6),
              let renderMesh = FFRenderMesh(mesh: mesh) else {
            return XCTFail("could not build the outline fixture")
        }

        let node = FFRenderNode(name: "Stone", mesh: renderMesh, material: .gem)
        let scene = FFViewportScene(nodes: [node])
        guard let bounds = scene.bounds else { return XCTFail("stone scene has no bounds") }
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.4)

        guard let plain = renderer.render(scene: scene, camera: camera, width: 240, height: 240) else {
            return XCTFail("unselected stone produced no readback")
        }
        let plainOutline = countOutlinePixels(plain)
        XCTAssertEqual(plainOutline, 0, "an unselected node drew the outline colour")

        let selected = scene.selecting([node.id])
        guard let outlined = renderer.render(scene: selected, camera: camera, width: 240, height: 240) else {
            return XCTFail("selected stone produced no readback")
        }
        attach(outlined, name: "phase13-selection-outline")

        let selectedOutline = countOutlinePixels(outlined)
        XCTAssertGreaterThan(selectedOutline, 40, "the selected stone has no visible outline")
        XCTAssertNil(renderer.lastCommandBufferError)
    }

    func testCPUSubmitIsMeasuredAsABaseline() throws {
        let renderer = try makeRenderer()
        guard let mesh = FFMeshFactory.torus(
            majorRadius: 30,
            minorRadius: 4.5,
            majorSegments: 120,
            minorSegments: 56
        ), let renderMesh = FFRenderMesh(mesh: mesh) else {
            return XCTFail("could not build the baseline fixture")
        }
        let scene = FFViewportScene(nodes: [
            FFRenderNode(name: "Baseline shank", mesh: renderMesh, material: .gold),
        ])
        guard scene.bounds != nil else { return XCTFail("baseline scene has no bounds") }

        let started = CACurrentMediaTime()
        XCTAssertNotNil(renderer.render(scene: scene, camera: .standard, width: 320, height: 240))
        let wallMilliseconds = (CACurrentMediaTime() - started) * 1_000

        XCTAssertTrue(renderer.lastSubmitMilliseconds.isFinite)
        XCTAssertGreaterThan(renderer.lastSubmitMilliseconds, 0)
        XCTAssertLessThan(renderer.lastSubmitMilliseconds, 5_000, "simulator submit exceeded the gate ceiling")
        XCTAssertGreaterThan(wallMilliseconds, 0)

        let record = String(
            format: "phase13 CPU submit %.3f ms, wall %.3f ms, %d triangles (simulator, not a device claim)",
            renderer.lastSubmitMilliseconds,
            wallMilliseconds,
            renderMesh.triangleCount
        )
        let attachment = XCTAttachment(string: record)
        attachment.name = "phase13-cpu-submit-baseline"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testRealityKitBridgeBuildsBothDemoNodes() {
        let root = FFRealitySceneBuilder.makeRoot(for: .jewelleryDemo)
        XCTAssertEqual(root.children.count, 2)
        XCTAssertEqual(Set(root.children.map(\.name)), ["Shank", "Stone"])
    }

    private func makeRenderer() throws -> FFMetalViewportRenderer {
        guard let renderer = FFMetalViewportRenderer() else {
            throw XCTSkip("Metal device unavailable on this simulator")
        }
        return renderer
    }

    private func attach(_ readback: FFViewportReadback, name: String) {
        guard let image = uiImage(from: readback) else { return }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Readback pixels are BGRA. Reorder them to RGBA so the xcresult
    /// attachment is a normal PNG the reviewer can open.
    private func uiImage(from readback: FFViewportReadback) -> UIImage? {
        let width = readback.width
        let height = readback.height
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        for offset in stride(from: 0, to: readback.pixels.count, by: 4) {
            rgba[offset] = readback.pixels[offset + 2]
            rgba[offset + 1] = readback.pixels[offset + 1]
            rgba[offset + 2] = readback.pixels[offset]
            rgba[offset + 3] = 255
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func classify(_ readback: FFViewportReadback) -> (lit: Int, gold: Int) {
        let pixels = readback.pixels
        let backgroundB = Int(pixels[0])
        let backgroundG = Int(pixels[1])
        let backgroundR = Int(pixels[2])
        var lit = 0
        var gold = 0

        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let b = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let r = Int(pixels[offset + 2])

            if abs(r - backgroundR) + abs(g - backgroundG) + abs(b - backgroundB) > 24 {
                lit += 1
            }
            if r > 80 && r > g && g > b {
                gold += 1
            }
        }
        return (lit, gold)
    }

    private func countOutlinePixels(_ readback: FFViewportReadback) -> Int {
        let pixels = readback.pixels
        var count = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let b = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let r = Int(pixels[offset + 2])
            if r >= 160, b >= 100, r > g + 40, b > g + 10 {
                count += 1
            }
        }
        return count
    }
}
