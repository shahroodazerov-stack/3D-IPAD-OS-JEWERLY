import UIKit
import XCTest
@testable import FacetForge

/// Phase 22's acceptance. One harness, six scenes, three consecutive renders of
/// each, one baseline manifest and one comparison rule. A drift names the scene,
/// the budget and where the fingerprint moved; changing a baseline requires the
/// dedicated `--update-baselines` scheme, which writes a diff artifact and a
/// git-tracked note as well as the new manifest.
final class Phase22SnapshotHarnessTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var baselineURL: URL {
        repositoryRoot.appendingPathComponent("FacetForgeTests/Baselines/render-snapshots.json")
    }

    private var noteURL: URL {
        repositoryRoot.appendingPathComponent("docs/evidence/render-snapshots.md")
    }

    private var artifactsDirectory: URL {
        repositoryRoot.appendingPathComponent(".dev-cache/render-baselines", isDirectory: true)
    }

    // MARK: - Determinism

    func testSixScenesAreStableAcrossThreeConsecutiveRenders() throws {
        let definitions = FFSnapshotScenes.all
        XCTAssertEqual(definitions.count, 6, "the gate is defined over exactly six scenes")
        XCTAssertEqual(
            definitions.map(\.name),
            [
                "bench-shaded",
                "bench-edges",
                "bench-wireframe",
                "bench-technical",
                "fixture-clay",
                "empty-grid"
            ],
            "the baseline set must stay explicit and ordered"
        )
        XCTAssertEqual(Set(definitions.map(\.name)).count, 6)
        XCTAssertEqual(
            definitions.first(where: { $0.name == "bench-shaded" })?.scene.nodes.count,
            2,
            "the bench scene lost its shank or stone"
        )
        XCTAssertEqual(
            definitions.first(where: { $0.name == "fixture-clay" })?.scene.nodes.count,
            2,
            "the clay fixture did not build"
        )
        XCTAssertTrue(
            definitions.first(where: { $0.name == "empty-grid" })?.scene.nodes.isEmpty == true,
            "the empty scene must draw only the grid"
        )

        let renderer = try makeRenderer()

        for definition in definitions {
            var hashes: [FFPerceptualHash] = []
            for index in 0..<3 {
                let capture = try XCTUnwrap(
                    FFSnapshotHarness.capture(definition, with: renderer),
                    "scene \(definition.name) produced no readback on render \(index + 1)"
                )
                hashes.append(capture.hash)
                if index == 0, let image = FFSnapshotHarness.image(for: capture.readback) {
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "phase22-\(definition.name)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }

            print(
                "phase22 render scene=\(definition.name) hash=\(hashes[0].hex)"
                    + " repeats=\(hashes.count) identical=\(Set(hashes).count == 1)"
            )
            XCTAssertEqual(
                Set(hashes).count,
                1,
                "scene \(definition.name) is not deterministic across three consecutive renders: "
                    + hashes.map(\.hex).joined(separator: ", ")
            )
        }
    }

    // MARK: - Committed baseline

    func testCommittedBaselinesMatchUnlessUpdateWasRequested() throws {
        let updateRequested = ProcessInfo.processInfo.arguments.contains("--update-baselines")
        let renderer = try makeRenderer()

        let manifest: FFSnapshotManifest
        do {
            manifest = try FFSnapshotHarness.loadManifest(at: baselineURL)
        } catch {
            return XCTFail(
                "cannot read the render baseline at \(baselineURL.path): \(error). "
                    + "Run scripts/render-baselines.sh --update-baselines to capture it explicitly."
            )
        }

        XCTAssertEqual(manifest.version, FFSnapshotManifest.currentVersion)
        XCTAssertEqual(manifest.algorithm, FFPerceptualHash.algorithm)
        XCTAssertTrue(
            (0...FFPerceptualHash.bitCount).contains(manifest.budgetBits),
            "budget \(manifest.budgetBits) is outside the hash domain"
        )

        var updated = manifest
        var problems: [String] = []
        let definedNames = Set(FFSnapshotScenes.all.map(\.name))

        for definition in FFSnapshotScenes.all {
            let capture = try XCTUnwrap(
                FFSnapshotHarness.capture(definition, with: renderer),
                "scene \(definition.name) produced no readback"
            )
            let verdict = FFSnapshotHarness.compare(
                name: definition.name,
                hash: capture.hash,
                manifest: manifest
            )
            let previous = manifest.entry(named: definition.name)
                .flatMap { FFPerceptualHash(hex: $0.hash) }

            switch verdict {
            case .match(let distance):
                print(
                    "phase22 baseline scene=\(definition.name) hash=\(capture.hash.hex)"
                        + " distance=\(distance) budget=\(manifest.budgetBits) verdict=match"
                )

            case .missingBaseline:
                print(
                    "phase22 baseline scene=\(definition.name) hash=\(capture.hash.hex)"
                        + " distance=n/a budget=\(manifest.budgetBits) verdict=missing"
                )
                if updateRequested {
                    try FFSnapshotHarness.record(
                        name: definition.name,
                        hash: capture.hash,
                        previous: previous,
                        readback: capture.readback,
                        manifest: &updated,
                        artifactsDirectory: artifactsDirectory,
                        noteURL: noteURL
                    )
                } else {
                    problems.append(
                        "scene \"\(definition.name)\" has no baseline; measured \(capture.hash.hex). "
                            + "Run scripts/render-baselines.sh --update-baselines to review and record it."
                    )
                }

            case .drift(let drift):
                print(
                    "phase22 baseline scene=\(definition.name) hash=\(capture.hash.hex)"
                        + " distance=\(drift.distance) budget=\(drift.budget) verdict=drift"
                )
                if updateRequested {
                    try FFSnapshotHarness.record(
                        name: definition.name,
                        hash: capture.hash,
                        previous: previous,
                        readback: capture.readback,
                        manifest: &updated,
                        artifactsDirectory: artifactsDirectory,
                        noteURL: noteURL
                    )
                } else {
                    problems.append(
                        "\(drift.summary). Run scripts/render-baselines.sh --update-baselines "
                            + "only if the change is intended."
                    )
                }

            case .invalidManifest(let message):
                problems.append("scene \"\(definition.name)\": \(message)")
            }
        }

        let storedNames = Set(manifest.scenes.map(\.name))
        for stale in storedNames.subtracting(definedNames).sorted() {
            if updateRequested {
                updated.removeEntries(notIn: definedNames)
                print("phase22 baseline scene=\(stale) verdict=stale-entry-removed")
            } else {
                problems.append(
                    "baseline contains scene \"\(stale)\" with no definition; remove it explicitly"
                )
            }
        }

        if updateRequested {
            try FFSnapshotHarness.writeManifest(updated, to: baselineURL)
            print("phase22 baseline update written to \(baselineURL.path)")
            print("Review the manifest diff and \(noteURL.path), then commit both.")
        } else {
            XCTAssertTrue(
                problems.isEmpty,
                "render baseline drift:\n" + problems.joined(separator: "\n")
            )
        }
    }

    // MARK: - The review rule

    func testABaselineChangeIsRejectedUntilUpdateIsRequested() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("facetforge-phase22-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let baselineURL = directory.appendingPathComponent("render-snapshots.json")
        let noteURL = directory.appendingPathComponent("render-snapshots.md")
        let artifactsDirectory = directory.appendingPathComponent("diffs", isDirectory: true)

        let original = syntheticReadback(reverseLowerHalf: false)
        let changed = syntheticReadback(reverseLowerHalf: true)
        let originalHash = FFPerceptualHash(readback: original)
        let changedHash = FFPerceptualHash(readback: changed)
        XCTAssertNotEqual(originalHash, changedHash)

        var manifest = FFSnapshotManifest.empty
        manifest.setEntry(named: "review-fixture", hash: originalHash)
        try FFSnapshotHarness.writeManifest(manifest, to: baselineURL)

        // Without the flag, a changed render is a loud rejection: the report
        // names the scene, the budget and where the drift sits, and nothing is
        // written.
        let verdict = FFSnapshotHarness.compare(
            name: "review-fixture",
            hash: changedHash,
            manifest: manifest
        )
        guard case .drift(let drift) = verdict else {
            return XCTFail("a changed render was accepted as \(verdict)")
        }
        XCTAssertGreaterThan(drift.distance, manifest.budgetBits)
        XCTAssertTrue(drift.summary.contains("review-fixture"), drift.summary)
        XCTAssertTrue(drift.summary.contains("budget \(manifest.budgetBits)"), drift.summary)
        XCTAssertTrue(drift.summary.contains("lower-"), "the report did not localise the drift: \(drift.summary)")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: artifactsDirectory.path),
            "the comparison wrote a diff artifact without the update flag"
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: noteURL.path),
            "the comparison wrote a note without the update flag"
        )
        XCTAssertEqual(
            try FFSnapshotHarness.loadManifest(at: baselineURL).entry(named: "review-fixture")?.hash,
            originalHash.hex,
            "the comparison changed the stored baseline"
        )

        // With --update-baselines passed, the same drift is recorded: the new
        // hash, a diff artifact and the git-tracked note.
        let update = try FFSnapshotHarness.record(
            name: "review-fixture",
            hash: changedHash,
            previous: originalHash,
            readback: changed,
            manifest: &manifest,
            artifactsDirectory: artifactsDirectory,
            noteURL: noteURL,
            timestamp: Date(timeIntervalSince1970: 1_760_000_000)
        )

        let artifactURL = try XCTUnwrap(update.artifactURL, "the update wrote no diff artifact")
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifactURL.path))
        let artifactData = try Data(contentsOf: artifactURL)
        XCTAssertGreaterThan(artifactData.count, 100, "the diff artifact is empty")
        XCTAssertEqual(manifest.entry(named: "review-fixture")?.hash, changedHash.hex)

        let note = try String(contentsOf: noteURL, encoding: .utf8)
        XCTAssertTrue(note.contains("review-fixture"), note)
        XCTAssertTrue(note.contains(changedHash.hex), note)
        XCTAssertTrue(note.contains("artifact"), note)

        try FFSnapshotHarness.writeManifest(manifest, to: baselineURL)
        let reloaded = try FFSnapshotHarness.loadManifest(at: baselineURL)
        XCTAssertEqual(reloaded.entry(named: "review-fixture")?.hash, changedHash.hex)
        XCTAssertEqual(
            FFSnapshotHarness.compare(name: "review-fixture", hash: changedHash, manifest: reloaded),
            .match(distance: 0)
        )
    }

    // MARK: - Helpers

    private func makeRenderer() throws -> FFMetalViewportRenderer {
        guard let renderer = FFMetalViewportRenderer() else {
            throw XCTSkip("Metal device unavailable on this simulator")
        }
        return renderer
    }

    /// A deterministic synthetic frame. The lower half reverses its horizontal
    /// gradient, which flips the lower eight rows of the difference hash — far
    /// outside an 8-bit budget, and localised enough to name a quadrant.
    private func syntheticReadback(reverseLowerHalf: Bool) -> FFViewportReadback {
        let width = 96
        let height = 64
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let position = 20 + (x * 200) / max(1, width - 1)
                let band = (y * 16) / max(1, height - 1)
                var value = position + band
                if reverseLowerHalf && y >= height / 2 {
                    value = 220 - (x * 200) / max(1, width - 1) + band
                }
                let gray = UInt8(clamping: value)
                pixels[offset] = gray
                pixels[offset + 1] = gray
                pixels[offset + 2] = gray
                pixels[offset + 3] = 255
            }
        }

        return FFViewportReadback(width: width, height: height, pixels: pixels)
    }
}
