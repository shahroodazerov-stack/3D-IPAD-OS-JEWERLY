import XCTest
@testable import FacetForge

final class UnitsTests: XCTestCase {
    func testMillimetreInchRoundTripsStayBelowOneMicroMillimetre() {
        let samples: [Double] = [0, 0.1, 1, 18, 25.4, 1_234.5]
        for millimetres in samples {
            let inches = FFLengthUnit.inches.value(fromMillimetres: millimetres)
            let back = FFLengthUnit.inches.millimetres(from: inches)
            XCTAssertEqual(back, millimetres, accuracy: 1e-6, "\(millimetres) mm")
            XCTAssertEqual(
                FFLengthUnit.millimetres.value(fromMillimetres: millimetres),
                millimetres,
                accuracy: 1e-12
            )
        }

        XCTAssertEqual(FFLengthUnit.inches.value(fromMillimetres: 25.4), 1, accuracy: 1e-12)
        XCTAssertEqual(FFLengthUnit.millimetres.millimetres(from: 0), 0, accuracy: 1e-12)
        let inchesLabel = FFLengthUnit.inches.formatted(millimetres: 18, decimals: 2)
        XCTAssertTrue(inchesLabel.hasPrefix("0.71"), inchesLabel)
        XCTAssertTrue(inchesLabel.hasSuffix(" in"), inchesLabel)
        XCTAssertEqual(FFLengthUnit.millimetres.formatted(millimetres: 18, decimals: 2), "18.00 mm")
    }

    func testUSRingSizeTableMatchesTheDomainDossier() {
        let table: [(size: Double, diameter: Double, circumference: Double)] = [
            (3, 14.07, 44.2),
            (4, 14.88, 46.8),
            (5, 15.70, 49.3),
            (6, 16.51, 51.9),
            (7, 17.32, 54.4),
            (8, 18.14, 57.0),
            (9, 18.95, 59.5),
            (10, 19.76, 62.1),
            (11, 20.57, 64.6),
            (12, 21.39, 67.2),
            (13, 22.20, 69.7),
        ]

        for row in table {
            let ring = FFRingSize(usSize: row.size)
            XCTAssertEqual(ring.innerDiameterMM, row.diameter, accuracy: 0.01, "US \(row.size) diameter")
            XCTAssertEqual(ring.innerCircumferenceMM, row.circumference, accuracy: 0.1, "US \(row.size) circumference")
            XCTAssertEqual(ring.usSize, row.size, accuracy: 1e-12, "US \(row.size) round trip")
            XCTAssertEqual(ring.innerRadiusMM * 2, ring.innerDiameterMM, accuracy: 1e-12)
        }
    }

    func testRingSizeCanBeAuthoredFromUSDiameterOrISOCircumference() {
        let us = FFRingSize(usSize: 6)
        XCTAssertEqual(FFRingSize(innerDiameterMM: us.innerDiameterMM).usSize, 6, accuracy: 1e-12)
        XCTAssertEqual(FFRingSize(innerCircumferenceMM: us.innerCircumferenceMM).usSize, 6, accuracy: 1e-12)

        // ISO 8653 reference points from dossier C: 41 and 76 mm circumference.
        let iso41 = FFRingSize(innerCircumferenceMM: 41)
        XCTAssertEqual(iso41.innerDiameterMM, 13.05, accuracy: 0.01)
        XCTAssertEqual(iso41.isoCircumferenceMM, 41, accuracy: 1e-9)
        XCTAssertEqual(iso41.isoLabel, "41")

        let iso76 = FFRingSize(innerCircumferenceMM: 76)
        XCTAssertEqual(iso76.innerDiameterMM, 24.19, accuracy: 0.01)
        XCTAssertEqual(iso76.isoLabel, "76")

        XCTAssertEqual(FFRingSize(usSize: 6) < FFRingSize(usSize: 7), true)
        XCTAssertEqual(FFRingSize(innerDiameterMM: .nan).innerDiameterMM, 16.5, accuracy: 1e-12)
    }

    func testGridSnapHonoursTenthHalfAndWholeMillimetreSteps() {
        let cases: [(value: Double, step: FFGridStep, expected: Double)] = [
            (0.06, .tenth, 0.1),
            (0.04, .tenth, 0.0),
            (-0.06, .tenth, -0.1),
            (0.24, .half, 0.0),
            (0.26, .half, 0.5),
            (1.74, .half, 1.5),
            (1.76, .half, 2.0),
            (2.49, .whole, 2.0),
            (2.51, .whole, 3.0),
            (-2.51, .whole, -3.0),
            (17.999, .whole, 18.0),
        ]

        for row in cases {
            XCTAssertEqual(
                FFGridSnap.snap(row.value, to: row.step),
                row.expected,
                accuracy: 1e-12,
                "\(row.value) on \(row.step.label)"
            )
        }

        let snapped = FFGridSnap.snap(
            Vec3(x: 1.23, y: -0.61, z: 9.98),
            to: .half
        )
        XCTAssertEqual(snapped.x, 1.0, accuracy: 1e-12)
        XCTAssertEqual(snapped.y, -0.5, accuracy: 1e-12)
        XCTAssertEqual(snapped.z, 10.0, accuracy: 1e-12)

        XCTAssertTrue(FFGridSnap.snap(.nan, to: 1).isNaN)
        XCTAssertEqual(FFGridSnap.snap(1.2, to: 0), 1.2, accuracy: 1e-12)
    }

    func testTheModellingGridIsOneMillimetreAtEveryStep() {
        XCTAssertEqual(FFGridStep.tenth.millimetres, 0.1, accuracy: 1e-12)
        XCTAssertEqual(FFGridStep.half.millimetres, 0.5, accuracy: 1e-12)
        XCTAssertEqual(FFGridStep.whole.millimetres, 1, accuracy: 1e-12)
        XCTAssertEqual(FFViewportGeometry.defaultSpacing, 1, accuracy: 1e-12)

        let vertices = FFViewportGeometry.gridAndAxes()
        XCTAssertEqual(vertices.count, (4 * 40 + 3) * 2)
        // The y axis also sits at x = 0, so select the z axis by its non-zero z
        // span. It runs from -40 to +40 and contributes exactly two endpoints,
        // one on each side of the origin; no grid line shares that pair because
        // the grid loop skips index 0.
        let zAxisEnds = vertices.filter { $0.position.x == 0 && $0.position.z != 0 }
        XCTAssertEqual(zAxisEnds.count, 2, "the z axis should be the only line at x = 0")
        XCTAssertEqual(zAxisEnds.filter { $0.position.z < 0 }.count, 1)
        XCTAssertEqual(zAxisEnds.filter { $0.position.z > 0 }.count, 1)
    }

    func testScaleBarIsLegibleAtFourPerspectiveAndFourOrthographicZooms() throws {
        let viewport = Vec2(x: 1_024, y: 768)

        for distance in [40.0, 150.0, 600.0, 2_500.0] {
            var camera = FFCamera.standard
            camera.dolly(by: FFCamera.standard.distance / distance)
            let units = try XCTUnwrap(camera.worldUnitsPerPoint(viewport: viewport))
            let plan = try XCTUnwrap(FFScaleBar.plan(millimetresPerPoint: units))
            assertLegible(plan, unitsPerPoint: units)
        }

        for height in [20.0, 90.0, 400.0, 1_600.0] {
            var camera = FFCamera.standard
            camera.setProjection(.orthographic)
            camera.setOrthographicHeight(height)
            let units = try XCTUnwrap(camera.worldUnitsPerPoint(viewport: viewport))
            let plan = try XCTUnwrap(FFScaleBar.plan(millimetresPerPoint: units))
            assertLegible(plan, unitsPerPoint: units)
        }
    }

    func testScaleBarLengthIsOneTwoOrFiveTimesADecade() {
        for units in stride(from: 0.001, through: 100, by: 0.137) {
            guard let plan = FFScaleBar.plan(millimetresPerPoint: units) else {
                return XCTFail("no plan for \(units) mm/pt")
            }
            let mantissa = plan.lengthMM / pow(10, floor(log10(plan.lengthMM)))
            XCTAssertTrue(
                [1.0, 2.0, 5.0].contains { abs(mantissa - $0) < 1e-9 },
                "\(plan.lengthMM) is not a 1-2-5 length"
            )
            XCTAssertTrue(plan.label.hasSuffix("mm"), plan.label)
        }
    }

    func testScaleBarRejectsNonPhysicalInputs() {
        XCTAssertNil(FFScaleBar.plan(millimetresPerPoint: 0))
        XCTAssertNil(FFScaleBar.plan(millimetresPerPoint: -1))
        XCTAssertNil(FFScaleBar.plan(millimetresPerPoint: .nan))
        XCTAssertNil(FFScaleBar.plan(millimetresPerPoint: 1, targetWidth: 0))
    }

    private func assertLegible(_ plan: FFScaleBarPlan, unitsPerPoint: Double) {
        let expectedWidth = plan.lengthMM / unitsPerPoint
        XCTAssertEqual(plan.pixelWidth, expectedWidth, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(plan.pixelWidth, FFScaleBar.targetWidth * 0.5)
        XCTAssertLessThanOrEqual(plan.pixelWidth, FFScaleBar.targetWidth * 1.5)
        XCTAssertEqual(
            FFLengthUnit.inches.value(fromMillimetres: plan.lengthMM),
            plan.lengthMM / FFLengthUnit.millimetresPerInch,
            accuracy: 1e-12
        )
    }
}
