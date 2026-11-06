import CryptoKit
import SwiftUI
import XCTest
@testable import FacetForge

/// Pixel digests for `FFComponentFixtures`. The first run fails with the
/// recorded values in the test log; those values are then committed here so
/// later changes are compared against a real rendering.
enum SnapshotBaseline {
    static let hashes: [String: String] = [:]
}

@MainActor
final class ComponentSnapshotTests: XCTestCase {
    func testComponentSnapshotsMatchTheRecordedBaseline() {
        var recorded: [String: String] = [:]
        var failures: [String] = []

        for item in FFComponentFixtures.cases {
            let content = item.view
                .frame(width: item.size.width, height: item.size.height)
                .background(FFPalette.canvas.color)
                .environment(\.colorScheme, .dark)

            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            renderer.isOpaque = true
            renderer.proposedSize = ProposedViewSize(width: item.size.width, height: item.size.height)

            guard let image = renderer.uiImage, let png = image.pngData() else {
                failures.append("\(item.id): ImageRenderer produced no PNG")
                continue
            }

            let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
            recorded[item.id] = digest

            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "component-\(item.id)"
            attachment.lifetime = .keepAlways
            add(attachment)

            if let expected = SnapshotBaseline.hashes[item.id], expected != digest {
                failures.append("\(item.id): expected \(expected), got \(digest)")
            } else if SnapshotBaseline.hashes[item.id] == nil {
                failures.append("\(item.id): no committed baseline")
            }
        }

        print("SNAPSHOT_MANIFEST_BEGIN")
        for id in recorded.keys.sorted() {
            print("SNAPSHOT \(id) \(recorded[id]!)")
        }
        print("SNAPSHOT_MANIFEST_END")

        if SnapshotBaseline.hashes.isEmpty {
            XCTFail("Snapshot baseline is empty. Commit the SNAPSHOT lines from this run into SnapshotBaseline.hashes.")
        } else {
            let missing = Set(SnapshotBaseline.hashes.keys).subtracting(recorded.keys)
            if !missing.isEmpty {
                failures.append("stale baselines: \(missing.sorted().joined(separator: ", "))")
            }
            XCTAssertTrue(
                failures.isEmpty,
                "Component snapshots changed:\n" + failures.joined(separator: "\n")
            )
        }
    }
}
