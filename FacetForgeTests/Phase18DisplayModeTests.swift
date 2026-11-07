import Metal
import UIKit
import XCTest
@testable import FacetForge

/// Phase 18's acceptance. Every display mode is rendered offscreen to real
/// pixels, not merely constructed, and the modes are told apart by what they
/// put on screen: Technical's light sheet, Clay's material override, Wireframe's
/// missing faces, Shaded-with-edges' extra line work. The saved document is
/// then written to disk and reopened to prove each viewport's mode survives.
final class Phase18DisplayModeTests: XCTestCase {
    // MARK: - The mode row

    func testModeRowHasFiveModesInChipOrder() {
        XCTAssertEqual(
            FFDisplayMode.allCases,
            [.shaded, .shadedEdges, .clay, .wireframe, .technical]
        )
        XCTAssertEqual(FFDisplayMode.technical.next, .shaded)
        XCTAssertEqual(FFDisplayMode.shaded.next, .shadedEdges)

        XCTAssertFalse(FFDisplayMode.wireframe.drawsFaces)
        XCTAssertTrue(FFDisplayMode.shaded.drawsFaces)
        XCTAssertTrue(FFDisplayMode.technical.drawsEdges)
        XCTAssertFalse(FFDisplayMode.shaded.drawsEdges)
        XCTAssertFalse(FFDisplayMode.wireframe.showsGrid)
        XCTAssertFalse(FFDisplayMode.technical.showsGrid)

        XCTAssertNotNil(FFDisplayMode.clay.materialOverride)
        XCTAssertNotNil(FFDisplayMode.technical.materialOverride)
        XCTAssertNil(FFDisplayMode.shaded.materialOverride)
        XCTAssertNil(FFDisplayMode.wireframe.materialOverride)
    }

    // MARK: - Snapshot render per mode

    func testEveryModeRendersItsOwnSignature() throws {
        let renderer = try makeRenderer()
        let fixture = try makeFixtureScene()
        guard let bounds = fixture.bounds else { return XCTFail("fixture has no bounds") }
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.25)

        let width = 320
        let height = 240
        guard let ids = renderer.pickBuffer(
            width: width,
            height: height,
            camera: camera,
            scene: fixture
        ) else {
            return XCTFail("the ID buffer for the fixture did not render")
        }
        let silhouette = ids.objectIDs.filter { $0 != 0 }.count
        XCTAssertGreaterThan(silhouette, 2_000, "the mode fixture covers too few pixels to compare")

        var signatures: [FFDisplayMode: Signature] = [:]
        for mode in FFDisplayMode.allCases {
            guard let readback = renderer.renderOffscreen(
                width: width,
                height: height,
                camera: camera,
                scene: fixture,
                mode: mode
            ) else {
                return XCTFail("\(mode.rawValue) produced no readback")
            }
            XCTAssertNil(renderer.lastCommandBufferError, "\(mode.rawValue) command buffer failed")

            let signature = classify(readback, ids: ids)
            signatures[mode] = signature

            XCTAssertGreaterThan(signature.lit, 500, "\(mode.rawValue) drew almost nothing")

            switch mode {
            case .technical:
                XCTAssertGreaterThan(
                    signature.corner.0 + signature.corner.1 + signature.corner.2,
                    600,
                    "Technical did not draw its light sheet"
                )
            case .shaded, .shadedEdges, .clay, .wireframe:
                XCTAssertLessThan(
                    signature.corner.0 + signature.corner.1 + signature.corner.2,
                    300,
                    "\(mode.rawValue) did not draw the dark studio background"
                )
            }

            let backgroundRatio = Double(signature.backgroundInside) / Double(max(1, silhouette))
            switch mode {
            case .shaded, .shadedEdges, .clay, .technical:
                XCTAssertLessThan(
                    backgroundRatio,
                    0.25,
                    "\(mode.rawValue) left holes in its faces"
                )
            case .wireframe:
                XCTAssertGreaterThan(
                    backgroundRatio,
                    0.50,
                    "Wireframe filled its faces instead of drawing edges"
                )
            }
        }

        let shaded = try XCTUnwrap(signatures[.shaded])
        let edges = try XCTUnwrap(signatures[.shadedEdges])
        let clay = try XCTUnwrap(signatures[.clay])
        let wire = try XCTUnwrap(signatures[.wireframe])
        let technical = try XCTUnwrap(signatures[.technical])

        // The material override really removes the document's warm gold and
        // keeps a near-neutral working clay; Technical and Wireframe have no
        // warm surfaces at all.
        XCTAssertGreaterThan(shaded.warm, 100, "Shaded did not shade the gold shank")
        XCTAssertGreaterThan(edges.warm, 100, "Shaded with edges lost the gold material")
        XCTAssertEqual(clay.warm, 0, "Clay kept the document material instead of overriding it")
        XCTAssertEqual(technical.warm, 0, "Technical kept the document material")
        XCTAssertEqual(wire.warm, 0, "Wireframe drew shaded faces")

        // Shaded-with-edges is Shaded plus line work, not a different shading.
        XCTAssertGreaterThan(
            edges.difference(from: shaded),
            200,
            "Shaded with edges drew no extra edge pixels"
        )
        XCTAssertGreaterThan(
            shaded.difference(from: wire),
            2_000,
            "Wireframe is indistinguishable from Shaded"
        )

        let fingerprints = signatures.values.map(\.fingerprint)
        XCTAssertEqual(Set(fingerprints).count, FFDisplayMode.allCases.count, "two modes render identically")

        // Evidence: the same five modes on the real bench sample, not the
        // comparison fixture, so a reviewer sees the shipping scene.
        try attachBenchRenders(renderer: renderer)
    }

    // MARK: - Persistence across save and reopen

    func testModePersistsAcrossSaveAndReopenPerViewport() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("facetforge-phase18-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ring.facetforge.json")

        let document = FFDocument.benchSample.document
        let session = FFEditorSession(document: document)
        XCTAssertTrue(session.setDisplayMode(.technical, for: "perspective"))
        XCTAssertTrue(session.setDisplayMode(.wireframe, for: "top"))
        XCTAssertTrue(session.documentSession.canUndo, "the mode did not go through the document session")
        try session.save(to: url)

        let saved = try FFDocument.decoded(from: Data(contentsOf: url))
        XCTAssertEqual(saved.displayModes["perspective"], .technical)
        XCTAssertEqual(saved.displayModes["top"], .wireframe)

        let reopened = FFEditorSession(document: FFDocument())
        try reopened.reopen(from: url)

        XCTAssertEqual(reopened.displayMode(for: "perspective"), .technical)
        XCTAssertEqual(reopened.displayMode(for: "top"), .wireframe)
        XCTAssertEqual(reopened.displayMode(for: "front"), .shaded, "an unset pane should open Shaded")
        XCTAssertEqual(reopened.scene.nodes.count, 2)
        XCTAssertEqual(reopened.scene.nodes.map(\.name), ["Shank", "Stone"])
        XCTAssertEqual(reopened.scene.nodes.first(where: { $0.name == "Stone" })?.kind, .stone)
        XCTAssertEqual(reopened.documentURL, url)
    }

    func testAnOlderDocumentWithoutDisplayModesStillDecodes() throws {
        let gold = FFMaterial(name: "Gold")
        let legacy = FFDocument(name: "Legacy", materials: [gold], rootNodes: [FFNode(name: "Bench")])
        var json = try XCTUnwrap(
            String(data: legacy.encoded(), encoding: .utf8)
        )
        // A schema-1 file written before this phase has no displayModes key.
        // Sorted keys put the field first, so it is stripped with its comma.
        json = json.replacingOccurrences(of: "\"displayModes\":{},", with: "")
        XCTAssertFalse(json.contains("displayModes"))
        let decoded = try FFDocument.decoded(from: Data(json.utf8))
        XCTAssertTrue(decoded.displayModes.isEmpty)
    }

    // MARK: - Helpers

    private struct Signature {
        let corner: (Int, Int, Int)
        let lit: Int
        let backgroundInside: Int
        /// Strongly warm pixels: r − b > 60. Gold has a wide margin; the clay
        /// override is a near-neutral grey and must score zero.
        let warm: Int
        let fingerprint: Int
        let pixels: [UInt8]

        func difference(from other: Signature) -> Int {
            guard pixels.count == other.pixels.count else { return pixels.count }
            var count = 0
            for offset in stride(from: 0, to: pixels.count, by: 4) {
                let delta = abs(Int(pixels[offset]) - Int(other.pixels[offset]))
                    + abs(Int(pixels[offset + 1]) - Int(other.pixels[offset + 1]))
                    + abs(Int(pixels[offset + 2]) - Int(other.pixels[offset + 2]))
                if delta > 24 { count += 1 }
            }
            return count
        }
    }

    private func classify(_ readback: FFViewportReadback, ids: FFPickingReadback) -> Signature {
        let pixels = readback.pixels
        let corner = (Int(pixels[2]), Int(pixels[1]), Int(pixels[0]))
        var lit = 0
        var backgroundInside = 0
        var warm = 0
        var fingerprint = 0

        for pixel in 0..<(readback.width * readback.height) {
            let offset = pixel * 4
            let b = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let r = Int(pixels[offset + 2])
            let delta = abs(r - corner.0) + abs(g - corner.1) + abs(b - corner.2)
            if delta > 24 { lit += 1 }
            if ids.objectID(atX: pixel % readback.width, y: pixel / readback.width) != 0 {
                if delta <= 24 { backgroundInside += 1 }
                if r - b > 60, r > 90 { warm += 1 }
            }
            if pixel % 11 == 0 { fingerprint += r &* 31 &+ g &* 7 &+ b }
        }

        return Signature(
            corner: corner,
            lit: lit,
            backgroundInside: backgroundInside,
            warm: warm,
            fingerprint: fingerprint,
            pixels: pixels
        )
    }

    private func makeFixtureScene() throws -> FFViewportScene {
        var nodes: [FFRenderNode] = []
        let band = try XCTUnwrap(FFMeshFactory.torus(
            majorRadius: 30,
            minorRadius: 4.5,
            majorSegments: 48,
            minorSegments: 12
        ))
        let bandMesh = try XCTUnwrap(FFRenderMesh(mesh: band))
        nodes.append(FFRenderNode(
            name: "Fixture shank",
            mesh: bandMesh,
            transform: Mat4.rotationX(.pi / 2),
            material: .gold
        ))

        let stone = try XCTUnwrap(FFMeshFactory.octahedron(radius: 6))
        let stoneMesh = try XCTUnwrap(FFRenderMesh(mesh: stone))
        nodes.append(FFRenderNode(
            name: "Fixture stone",
            mesh: stoneMesh,
            transform: Mat4.translation(Vec3(x: 0, y: 40, z: 0)),
            material: .gem,
            kind: .stone
        ))
        return FFViewportScene(nodes: nodes)
    }

    private func attachBenchRenders(renderer: FFMetalViewportRenderer) throws {
        let scene = FFViewportScene.jewelleryDemo
        guard let bounds = scene.bounds else { return XCTFail("bench sample has no bounds") }
        var camera = FFCamera.standard
        camera.frame(bounds: bounds, padding: 1.25)

        for mode in FFDisplayMode.allCases {
            guard let readback = renderer.renderOffscreen(
                width: 480,
                height: 360,
                camera: camera,
                scene: scene,
                mode: mode
            ), let image = uiImage(from: readback) else {
                return XCTFail("\(mode.rawValue) bench render produced no image")
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "phase18-mode-\(mode.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func makeRenderer() throws -> FFMetalViewportRenderer {
        guard let renderer = FFMetalViewportRenderer() else {
            throw XCTSkip("Metal device unavailable on this simulator")
        }
        return renderer
    }

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
}
