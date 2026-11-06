import CryptoKit
import SwiftUI
import XCTest
@testable import FacetForge

/// Pixel digests for `FFComponentFixtures`. The first run fails with the
/// recorded values in the test log; those values are then committed here so
/// later changes are compared against a real rendering.
enum SnapshotBaseline {
    // Recorded on the macOS 26 runner from the committed fixtures. A change
    // here is a visible design change and must be reviewed as one.
    static let hashes: [String: String] = [
        "button": "6c8b25966b097ea61660e2f13ebc0f783f2a9778afdf3b3ccf9474f941ee356b",
        "chip": "f4cdbbc995e5c90b56671ba9c0e1bd395176ee5e38ea733f75be965bd91c3c93",
        "empty-state": "de0a9fa4c068f2d61cbcc948bfc7330782793f23c328bdb8f62b44872d2bfb16",
        "field": "ed57009f06272a9fcc3f979eed3b1f835a1b85a04f654e1bef35181499354b71",
        "list-row": "bf41d3027b5de69138b6e98466a7cf086143f7784e650d05df4c83903a37fc81",
        "panel": "257075d5e08ee458c3bd27c71629c302f043cc60afb10b6a67cbf79a04a0fdd9",
        "segmented": "28026aa57b65f2201a2e5500baa0629bfb268a07ab09dd876d35acb118f05176",
        "sheet": "ded23fd148ecf36f47eb9cc231b0d8ae926bc9fbbd2a6228f59af0f76277b4f2",
        "slider": "cb23dbdf54e8465d4350900c9ed56ed5476b0d57766419df9a6f31024ec10f08",
        "toast": "710e3439fd4ce3bb2eef31a6e0ea0acd25e152273465f7cb1c20b029c849cbc5",
        "toolbar": "55abe9f237655f0878edcba930712a44cee00b357eba423ea4b87e701e26f0d4",
        "tooltip": "ecb34488b8c9fb3b06e9d90bc8272a877a457a74a817ab3a679cfe7d519f4d87",
    ]
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
