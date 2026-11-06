import XCTest
@testable import FacetForge

/// Phase 4's layout snapshot is the frozen width table below. Any change to
/// column widths or breakpoint thresholds has to be made here as well, which
/// makes an accidental layout drift a test failure rather than a surprise on
/// a device.
final class LayoutSnapshotTests: XCTestCase {
    func testFiveWidthLayoutSnapshots() {
        let expected: [(width: CGFloat, breakpoint: FFBreakpoint, tools: CGFloat, inspector: CGFloat, viewport: CGFloat)] = [
            (640, .compact, 56, 208, 376),
            (700, .compact, 56, 208, 436),
            (820, .medium, 72, 240, 508),
            (1024, .regular, 80, 288, 656),
            (1366, .wide, 88, 320, 958),
        ]

        XCTAssertEqual(FFShellMetrics.testWidths, expected.map { $0.width })

        for row in expected {
            let metrics = FFShellMetrics.calculate(width: row.width)
            XCTAssertEqual(metrics.breakpoint, row.breakpoint, "breakpoint at \(row.width) pt")
            XCTAssertEqual(metrics.toolsWidth, row.tools, accuracy: 0.001, "tools at \(row.width) pt")
            XCTAssertEqual(metrics.inspectorWidth, row.inspector, accuracy: 0.001, "inspector at \(row.width) pt")
            XCTAssertEqual(metrics.viewportWidth, row.viewport, accuracy: 0.001, "viewport at \(row.width) pt")
            XCTAssertEqual(
                metrics.toolsWidth + metrics.viewportWidth + metrics.inspectorWidth,
                row.width,
                accuracy: 0.001,
                "columns must fill the shell exactly at \(row.width) pt"
            )
        }
    }

    func testBreakpointThresholdsAreInclusiveAtTheirMinimum() {
        XCTAssertEqual(FFBreakpoint(width: 639.9), .compact)
        XCTAssertEqual(FFBreakpoint(width: 640), .compact)
        XCTAssertEqual(FFBreakpoint(width: 819.9), .compact)
        XCTAssertEqual(FFBreakpoint(width: 820), .medium)
        XCTAssertEqual(FFBreakpoint(width: 1023.9), .medium)
        XCTAssertEqual(FFBreakpoint(width: 1024), .regular)
        XCTAssertEqual(FFBreakpoint(width: 1365.9), .regular)
        XCTAssertEqual(FFBreakpoint(width: 1366), .wide)
    }

    func testCollapsedPanelsReturnTheirWidthToTheViewport() {
        let base = FFShellMetrics.calculate(width: 640)
        let inspectorHidden = FFShellMetrics.calculate(width: 640, inspectorCollapsed: true)
        XCTAssertEqual(inspectorHidden.inspectorWidth, 0)
        XCTAssertEqual(inspectorHidden.viewportWidth, base.viewportWidth + base.inspectorWidth)

        let toolsHidden = FFShellMetrics.calculate(width: 640, toolsCollapsed: true)
        XCTAssertEqual(toolsHidden.toolsWidth, 0)
        XCTAssertEqual(toolsHidden.viewportWidth, base.viewportWidth + base.toolsWidth)

        let bothHidden = FFShellMetrics.calculate(width: 640, toolsCollapsed: true, inspectorCollapsed: true)
        XCTAssertEqual(bothHidden.viewportWidth, 640)
    }

    func testViewportKeepsItsMinimumWhenTheSceneIsNarrowerThanThePolicy() {
        let metrics = FFShellMetrics.calculate(width: 300)
        XCTAssertGreaterThanOrEqual(metrics.viewportWidth, 200)
        XCTAssertEqual(metrics.toolsWidth + metrics.inspectorWidth + metrics.viewportWidth, 300, accuracy: 0.001)
    }

    func testScenePolicyPinsTheCompactMinimum() {
        XCTAssertEqual(FFSceneSizePolicy.minimumSize, CGSize(width: 640, height: 480))
        XCTAssertEqual(FFSceneSizePolicy.summary, "min 640 pt")
    }
}
