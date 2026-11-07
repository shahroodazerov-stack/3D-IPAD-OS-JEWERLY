import Foundation
import UIKit

/// One named scene the render-snapshot gate draws. The definition owns
/// everything that affects the pixels — scene, camera, size and display mode —
/// so a scene cannot drift because a test forgot one of those inputs.
struct FFSnapshotScene {
    let name: String
    let width: Int
    let height: Int
    let mode: FFDisplayMode
    let scene: FFViewportScene
    let camera: FFCamera
}

/// Phase 22's six scenes, and the only place they are defined.
///
/// The four bench scenes exercise the shipping ring through the shaded, edge,
/// wireframe and technical passes; the fixture scene isolates the clay material
/// override on coarse geometry; the empty scene captures the grid and axes with
/// no document geometry at all. Later render phases add scenes here rather than
/// growing a second comparison path.
enum FFSnapshotScenes {
    static let width = 512
    static let height = 384

    static var all: [FFSnapshotScene] { definitions }

    private static let definitions: [FFSnapshotScene] = makeDefinitions()

    private static func makeDefinitions() -> [FFSnapshotScene] {
        let bench = FFViewportScene.jewelleryDemo
        let benchCamera = framed(bench)
        let fixture = makeFixture()
        let fixtureCamera = framed(fixture)

        return [
            FFSnapshotScene(
                name: "bench-shaded",
                width: width,
                height: height,
                mode: .shaded,
                scene: bench,
                camera: benchCamera
            ),
            FFSnapshotScene(
                name: "bench-edges",
                width: width,
                height: height,
                mode: .shadedEdges,
                scene: bench,
                camera: benchCamera
            ),
            FFSnapshotScene(
                name: "bench-wireframe",
                width: width,
                height: height,
                mode: .wireframe,
                scene: bench,
                camera: benchCamera
            ),
            FFSnapshotScene(
                name: "bench-technical",
                width: width,
                height: height,
                mode: .technical,
                scene: bench,
                camera: benchCamera
            ),
            FFSnapshotScene(
                name: "fixture-clay",
                width: width,
                height: height,
                mode: .clay,
                scene: fixture,
                camera: fixtureCamera
            ),
            FFSnapshotScene(
                name: "empty-grid",
                width: width,
                height: height,
                mode: .shaded,
                scene: .empty,
                camera: .standard
            )
        ]
    }

    private static func framed(_ scene: FFViewportScene) -> FFCamera {
        var camera = FFCamera.standard
        if let bounds = scene.bounds {
            camera.frame(bounds: bounds, padding: 1.25)
        }
        return camera
    }

    /// Two coarse octahedra, the fixture Phase 18 used for the display modes.
    /// Keeping it in the baseline set makes a shading regression visible on
    /// geometry whose facets are large enough to inspect by eye.
    private static func makeFixture() -> FFViewportScene {
        guard let facets = FFMeshFactory.octahedron(radius: 24),
              let facetMesh = FFRenderMesh(mesh: facets),
              let stone = FFMeshFactory.octahedron(radius: 7),
              let stoneMesh = FFRenderMesh(mesh: stone)
        else { return .empty }

        let neutralLine = FFRGBA(red: 0.72, green: 0.78, blue: 0.82)
        let shank = FFRenderNode(
            name: "Fixture shank",
            mesh: facetMesh,
            transform: Mat4.translation(Vec3(x: 0, y: 34, z: 0)),
            material: .gold,
            layerColor: neutralLine
        )
        let gem = FFRenderNode(
            name: "Fixture stone",
            mesh: stoneMesh,
            transform: Mat4.translation(Vec3(x: 0, y: 72, z: 0)),
            material: .gem,
            kind: .stone,
            layerColor: neutralLine
        )
        return FFViewportScene(nodes: [shank, gem])
    }
}

/// A 256-bit difference hash over a 17×16 grayscale grid. Adjacent cells decide
/// one bit each, so the fingerprint follows local structure rather than the
/// absolute exposure; identical pixels always produce an identical hex string.
///
/// This is the single hash the render snapshot gate uses. It is deliberately a
/// value with no image storage: a baseline is cheap to review in a diff, and a
/// changed render has to explain itself through the per-bit drift report instead
/// of hiding behind a tolerance on raw pixels.
struct FFPerceptualHash: Equatable, Hashable, Codable, CustomStringConvertible {
    static let algorithm = "dhash-17x16-256"
    static let bitCount = 256
    static let rows = 16
    static let columns = 16
    static let cellColumns = 17

    let hex: String

    init?(hex: String) {
        let normalized = hex.lowercased()
        guard normalized.count == 64,
              normalized.allSatisfy({ $0.isHexDigit })
        else { return nil }
        self.hex = normalized
    }

    init(readback: FFViewportReadback) {
        let width = max(1, readback.width)
        let height = max(1, readback.height)
        var luminance = [[Int]](
            repeating: [Int](repeating: 0, count: Self.cellColumns),
            count: Self.rows
        )

        for row in 0..<Self.rows {
            let y0 = row * height / Self.rows
            var y1 = (row + 1) * height / Self.rows
            if y1 <= y0 { y1 = min(height, y0 + 1) }

            for column in 0..<Self.cellColumns {
                let x0 = column * width / Self.cellColumns
                var x1 = (column + 1) * width / Self.cellColumns
                if x1 <= x0 { x1 = min(width, x0 + 1) }

                var sum = 0
                var count = 0
                for y in y0..<y1 {
                    let rowBase = y * width * 4
                    for x in x0..<x1 {
                        let offset = rowBase + x * 4
                        guard offset + 2 < readback.pixels.count else { continue }
                        let b = Int(readback.pixels[offset])
                        let g = Int(readback.pixels[offset + 1])
                        let r = Int(readback.pixels[offset + 2])
                        sum += (77 * r + 150 * g + 29 * b) >> 8
                        count += 1
                    }
                }
                if count > 0 {
                    luminance[row][column] = sum / count
                }
            }
        }

        var words = [UInt64](repeating: 0, count: 4)
        var bit = 0
        for row in 0..<Self.rows {
            for column in 0..<Self.columns {
                if luminance[row][column] > luminance[row][column + 1] {
                    words[bit / 64] |= UInt64(1) << UInt64(63 - bit % 64)
                }
                bit += 1
            }
        }
        self.hex = words.map(Self.hexWord).joined()
    }

    var description: String { hex }

    var words: [UInt64] {
        var result: [UInt64] = []
        var start = hex.startIndex
        for _ in 0..<4 {
            let end = hex.index(start, offsetBy: 16)
            result.append(UInt64(hex[start..<end], radix: 16) ?? 0)
            start = end
        }
        return result
    }

    /// Hamming distance: how many of the 256 structural decisions differ.
    func distance(to other: FFPerceptualHash) -> Int {
        zip(words, other.words).reduce(0) { total, pair in
            total + Int((pair.0 ^ pair.1).nonzeroBitCount)
        }
    }

    /// The bit indices that differ, ordered top-to-bottom and left-to-right.
    /// Each index maps to one 16×16 drift cell for the human-readable report and
    /// the diff image.
    func changedBits(comparedTo other: FFPerceptualHash) -> [Int] {
        let lhs = words
        let rhs = other.words
        var changed: [Int] = []
        changed.reserveCapacity(Int((lhs[0] ^ rhs[0]).nonzeroBitCount))
        for index in 0..<Self.bitCount {
            let word = index / 64
            let shift = UInt64(63 - index % 64)
            if ((lhs[word] ^ rhs[word]) >> shift) & 1 == 1 {
                changed.append(index)
            }
        }
        return changed
    }

    private static func hexWord(_ value: UInt64) -> String {
        let digits = String(value, radix: 16)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }
}

/// Why a render no longer matches its baseline. The summary always names the
/// scene, the allowed budget and where the fingerprint moved, so a red gate is
/// actionable without opening an artifact first.
struct FFSnapshotDrift: Equatable {
    let scene: String
    let distance: Int
    let budget: Int
    let changedBits: [Int]

    var summary: String {
        let rows = changedBits.map { $0 / FFPerceptualHash.columns }
        let columns = changedBits.map { $0 % FFPerceptualHash.columns }
        let rowRange = "rows \(rows.min() ?? 0)-\(rows.max() ?? 0)"
        let columnRange = "columns \(columns.min() ?? 0)-\(columns.max() ?? 0)"

        var quadrants = [String: Int]()
        for bit in changedBits {
            let row = bit / FFPerceptualHash.columns
            let column = bit % FFPerceptualHash.columns
            let vertical = row < FFPerceptualHash.rows / 2 ? "upper" : "lower"
            let horizontal = column < FFPerceptualHash.columns / 2 ? "left" : "right"
            quadrants["\(vertical)-\(horizontal)", default: 0] += 1
        }
        let named = quadrants
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key) \($0.value)" }
            .joined(separator: ", ")

        return "scene \"\(scene)\": \(distance) of \(FFPerceptualHash.bitCount) perceptual-hash bits differ"
            + " (budget \(budget)); changes in \(named); \(rowRange), \(columnRange)"
    }
}

enum FFSnapshotVerdict: Equatable {
    case match(distance: Int)
    case drift(FFSnapshotDrift)
    case missingBaseline
    case invalidManifest(String)
}

struct FFSnapshotBaselineEntry: Codable, Equatable {
    var name: String
    var hash: String
}

/// The one baseline format. A manifest names the hash algorithm and the allowed
/// Hamming distance once, then stores one hex hash per scene; there is no
/// per-scene tolerance and no stored image.
struct FFSnapshotManifest: Codable, Equatable {
    static let currentVersion = 1
    static let defaultBudgetBits = 8

    var version: Int
    var algorithm: String
    var budgetBits: Int
    var scenes: [FFSnapshotBaselineEntry]

    static var empty: FFSnapshotManifest {
        FFSnapshotManifest(
            version: currentVersion,
            algorithm: FFPerceptualHash.algorithm,
            budgetBits: defaultBudgetBits,
            scenes: []
        )
    }

    func entry(named name: String) -> FFSnapshotBaselineEntry? {
        scenes.first { $0.name == name }
    }

    mutating func setEntry(named name: String, hash: FFPerceptualHash) {
        if let index = scenes.firstIndex(where: { $0.name == name }) {
            scenes[index].hash = hash.hex
        } else {
            scenes.append(FFSnapshotBaselineEntry(name: name, hash: hash.hex))
        }
        scenes.sort { $0.name < $1.name }
    }

    mutating func removeEntries(notIn names: Set<String>) {
        scenes.removeAll { !names.contains($0.name) }
    }
}

struct FFSnapshotCapture {
    let scene: String
    let readback: FFViewportReadback
    let hash: FFPerceptualHash
}

struct FFSnapshotUpdate {
    let manifest: FFSnapshotManifest
    let artifactURL: URL?
    let noteLine: String
}

/// The single owner of render-snapshot logic: rendering a definition, hashing a
/// readback, comparing against a manifest, and writing the explicit review
/// output. Later phases call these functions instead of building their own
/// comparison or baseline format.
enum FFSnapshotHarness {
    // MARK: - Rendering and hashing

    static func capture(
        _ definition: FFSnapshotScene,
        with renderer: FFMetalViewportRenderer
    ) -> FFSnapshotCapture? {
        guard let readback = renderer.renderOffscreen(
            width: definition.width,
            height: definition.height,
            camera: definition.camera,
            scene: definition.scene,
            mode: definition.mode
        ) else { return nil }
        return FFSnapshotCapture(
            scene: definition.name,
            readback: readback,
            hash: FFPerceptualHash(readback: readback)
        )
    }

    // MARK: - Baseline storage

    static func loadManifest(at url: URL) throws -> FFSnapshotManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FFSnapshotManifest.self, from: data)
    }

    static func writeManifest(_ manifest: FFSnapshotManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(manifest)
        data.append(0x0a)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    // MARK: - The one comparison rule

    static func compare(
        name: String,
        hash: FFPerceptualHash,
        manifest: FFSnapshotManifest
    ) -> FFSnapshotVerdict {
        guard manifest.version == FFSnapshotManifest.currentVersion else {
            return .invalidManifest(
                "baseline version \(manifest.version) is not \(FFSnapshotManifest.currentVersion)"
            )
        }
        guard manifest.algorithm == FFPerceptualHash.algorithm else {
            return .invalidManifest(
                "baseline algorithm \"\(manifest.algorithm)\" is not \"\(FFPerceptualHash.algorithm)\""
            )
        }
        guard (0...FFPerceptualHash.bitCount).contains(manifest.budgetBits) else {
            return .invalidManifest(
                "baseline budget \(manifest.budgetBits) is outside 0...\(FFPerceptualHash.bitCount)"
            )
        }
        guard let entry = manifest.entry(named: name) else {
            return .missingBaseline
        }
        guard let baseline = FFPerceptualHash(hex: entry.hash) else {
            return .invalidManifest("scene \"\(name)\" has a malformed hash \"\(entry.hash)\"")
        }

        let distance = hash.distance(to: baseline)
        if distance <= manifest.budgetBits {
            return .match(distance: distance)
        }
        return .drift(FFSnapshotDrift(
            scene: name,
            distance: distance,
            budget: manifest.budgetBits,
            changedBits: hash.changedBits(comparedTo: baseline)
        ))
    }

    // MARK: - Explicit review path

    /// Records one scene's new hash. This is only reached when the caller has
    /// decided to update, which is why it lives behind the dedicated scheme and
    /// script rather than behind a test that discovers drift.
    ///
    /// It writes the diff artifact (when there is a previous hash and readback)
    /// and appends a line to the git-tracked note, then updates the in-memory
    /// manifest. Nothing is written to the baseline until the caller saves the
    /// returned manifest.
    @discardableResult
    static func record(
        name: String,
        hash: FFPerceptualHash,
        previous: FFPerceptualHash?,
        readback: FFViewportReadback?,
        manifest: inout FFSnapshotManifest,
        artifactsDirectory: URL,
        noteURL: URL,
        timestamp: Date = Date()
    ) throws -> FFSnapshotUpdate {
        var artifactURL: URL?
        var detail = "no previous baseline; recorded \(hash.hex)"

        if let previous {
            let distance = hash.distance(to: previous)
            let changed = hash.changedBits(comparedTo: previous)
            if distance <= manifest.budgetBits {
                detail = "refreshed within budget (\(distance)/\(FFPerceptualHash.bitCount) bits)"
            } else {
                detail = FFSnapshotDrift(
                    scene: name,
                    distance: distance,
                    budget: manifest.budgetBits,
                    changedBits: changed
                ).summary
            }

            if let readback,
               let data = diffPNGData(for: readback, changedBits: changed) {
                try FileManager.default.createDirectory(
                    at: artifactsDirectory,
                    withIntermediateDirectories: true
                )
                let url = artifactsDirectory.appendingPathComponent("\(name)-diff.png")
                try data.write(to: url, options: .atomic)
                artifactURL = url
            }
        }

        manifest.setEntry(named: name, hash: hash)

        var line = "- \(timestampString(timestamp)) · `\(name)` · \(detail)"
        line += " · new hash `\(hash.hex)`"
        if let artifactURL {
            line += " · artifact `\(artifactsDirectory.lastPathComponent)/\(artifactURL.lastPathComponent)`"
        }
        try appendNote(line, to: noteURL)

        return FFSnapshotUpdate(manifest: manifest, artifactURL: artifactURL, noteLine: line)
    }

    static let noteHeader = """
    # Render snapshot baseline updates

    Appended only by `scripts/render-baselines.sh --update-baselines`. Every line records one
    reviewed change to `FacetForgeTests/Baselines/render-snapshots.json`: the scene, the measured
    drift from the previous hash, the replacement hash and the diff artifact. Commit this file with
    the baseline manifest so the change is reviewable in history.

    """

    static func appendNote(_ line: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var text = (try? String(contentsOf: url, encoding: .utf8)) ?? noteHeader
        if !text.hasSuffix("\n") { text += "\n" }
        text += line + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func timestampString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    // MARK: - Images

    static func image(for readback: FFViewportReadback) -> UIImage? {
        guard let data = pngData(
            width: readback.width,
            height: readback.height,
            pixels: readback.pixels,
            convertBGRA: true
        ) else { return nil }
        return UIImage(data: data)
    }

    /// The current render with the changed hash cells painted magenta, so a
    /// reviewer can see which part of the frame moved rather than only read a
    /// distance.
    static func diffPNGData(for readback: FFViewportReadback, changedBits: [Int]) -> Data? {
        guard readback.width > 0,
              readback.height > 0,
              readback.pixels.count >= readback.width * readback.height * 4
        else { return nil }

        var rgba = [UInt8](repeating: 0, count: readback.width * readback.height * 4)
        for offset in stride(from: 0, to: rgba.count, by: 4) {
            rgba[offset] = readback.pixels[offset + 2]
            rgba[offset + 1] = readback.pixels[offset + 1]
            rgba[offset + 2] = readback.pixels[offset]
            rgba[offset + 3] = 255
        }

        for bit in changedBits {
            let row = bit / FFPerceptualHash.columns
            let column = bit % FFPerceptualHash.columns
            paintCell(row: row, column: column, width: readback.width, height: readback.height, in: &rgba)
            paintCell(row: row, column: column + 1, width: readback.width, height: readback.height, in: &rgba)
        }

        return pngData(width: readback.width, height: readback.height, pixels: rgba, convertBGRA: false)
    }

    private static func paintCell(
        row: Int,
        column: Int,
        width: Int,
        height: Int,
        in rgba: inout [UInt8]
    ) {
        guard row >= 0, row < FFPerceptualHash.rows,
              column >= 0, column < FFPerceptualHash.cellColumns
        else { return }

        let x0 = column * width / FFPerceptualHash.cellColumns
        let x1 = min(width, max(x0 + 1, (column + 1) * width / FFPerceptualHash.cellColumns))
        let y0 = row * height / FFPerceptualHash.rows
        let y1 = min(height, max(y0 + 1, (row + 1) * height / FFPerceptualHash.rows))

        for y in y0..<y1 {
            for x in x0..<x1 {
                let offset = (y * width + x) * 4
                rgba[offset] = UInt8((Int(rgba[offset]) + 255) / 2)
                rgba[offset + 1] = UInt8(Int(rgba[offset + 1]) / 2)
                rgba[offset + 2] = UInt8((Int(rgba[offset + 2]) + 255) / 2)
            }
        }
    }

    private static func pngData(
        width: Int,
        height: Int,
        pixels: [UInt8],
        convertBGRA: Bool
    ) -> Data? {
        var rgba = pixels
        if convertBGRA {
            guard pixels.count >= width * height * 4 else { return nil }
            for offset in stride(from: 0, to: rgba.count, by: 4) {
                rgba[offset] = pixels[offset + 2]
                rgba[offset + 1] = pixels[offset + 1]
                rgba[offset + 2] = pixels[offset]
                rgba[offset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let image = CGImage(
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
              )
        else { return nil }
        return UIImage(cgImage: image).pngData()
    }
}
