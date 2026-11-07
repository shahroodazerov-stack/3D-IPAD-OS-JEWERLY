import SwiftUI

/// An on-screen measurement label that has already been placed. The anchor is
/// where the measurement projects; the rect is where the chip actually sits
/// after the layout clamps it inside the viewport.
struct FFMeasurementLabelPlacement: Equatable {
    let text: String
    let fontSize: CGFloat
    let anchor: Vec2
    let rect: CGRect
}

/// The measurement layer of the viewport: the committed measurements, the
/// draft points and their labels. Nothing here is hittable, so measuring never
/// steals a camera gesture; the card that chooses the kind is a sibling view.
struct FFMeasurementOverlay: View {
    @ObservedObject var session: FFMeasurementSession
    let camera: FFCamera
    let viewport: CGSize
    let unit: FFLengthUnit

    private var viewportVector: Vec2 {
        Vec2(x: Double(viewport.width), y: Double(viewport.height))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for measurement in session.measurements {
                    draw(measurement, in: &context)
                }
                drawDraft(in: &context)
            }
            .allowsHitTesting(false)

            ForEach(session.measurements) { measurement in
                if let item = placement(for: measurement) {
                    label(item)
                }
            }
        }
        .frame(width: viewport.width, height: viewport.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
    }

    /// Places a label from the measurement's value and projected anchor. A
    /// measurement whose points cannot all be projected gets no label rather
    /// than a label pinned to an arbitrary corner.
    func placement(for measurement: FFMeasurement) -> FFMeasurementLabelPlacement? {
        let text = measurement.displayText(unit)
        guard !text.isEmpty, text != "—" else { return nil }
        let screens = measurement.points.compactMap {
            camera.screenPoint(for: $0.position, viewport: viewportVector)
        }
        guard screens.count == measurement.points.count, !screens.isEmpty else { return nil }
        let anchor = screens.reduce(Vec2.zero, +) * (1 / Double(screens.count))
        guard let layout = FFMeasurementLabelLayout.label(
            text: text,
            anchor: anchor,
            viewport: viewportVector
        ) else { return nil }
        return FFMeasurementLabelPlacement(
            text: text,
            fontSize: layout.fontSize,
            anchor: anchor,
            rect: layout.rect
        )
    }

    private func label(_ placement: FFMeasurementLabelPlacement) -> some View {
        Text(placement.text)
            .font(.system(size: placement.fontSize, weight: .medium))
            .foregroundStyle(FFPalette.textPrimary.color)
            .padding(.horizontal, FFMeasurementLabelLayout.horizontalPadding)
            .padding(.vertical, FFMeasurementLabelLayout.verticalPadding)
            .background(
                FFPalette.panel.color,
                in: RoundedRectangle(cornerRadius: FFRadius.xs, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: FFRadius.xs, style: .continuous)
                    .stroke(FFPalette.accent.color.opacity(0.65), lineWidth: 1)
            }
            .position(x: placement.rect.midX, y: placement.rect.midY)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("shell.measure.label")
            .accessibilityLabel("Measurement")
            .accessibilityValue(placement.text)
    }

    private func draw(_ measurement: FFMeasurement, in context: inout GraphicsContext) {
        let screens = measurement.points.compactMap {
            camera.screenPoint(for: $0.position, viewport: viewportVector)
        }
        guard screens.count >= 2 else { return }

        var path = Path()
        path.addLines(screens.map { CGPoint(x: $0.x, y: $0.y) })
        context.stroke(
            path,
            with: .color(FFPalette.accent.color),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
        for screen in screens {
            context.fill(
                Path(ellipseIn: CGRect(x: screen.x - 2.5, y: screen.y - 2.5, width: 5, height: 5)),
                with: .color(FFPalette.accent.color)
            )
        }
    }

    /// The draft is drawn dashed and hollow so an unfinished measurement cannot
    /// be mistaken for a committed one.
    private func drawDraft(in context: inout GraphicsContext) {
        let screens = session.draft.compactMap {
            camera.screenPoint(for: $0.position, viewport: viewportVector)
        }
        guard !screens.isEmpty else { return }
        if screens.count >= 2 {
            var path = Path()
            path.addLines(screens.map { CGPoint(x: $0.x, y: $0.y) })
            context.stroke(
                path,
                with: .color(FFPalette.textAccent.color),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
        }
        for screen in screens {
            context.stroke(
                Path(ellipseIn: CGRect(x: screen.x - 4, y: screen.y - 4, width: 8, height: 8)),
                with: .color(FFPalette.textAccent.color),
                lineWidth: 1.5
            )
        }
    }
}

/// The measurement card. It is the tool's whole interface: pick a kind, see the
/// live value or the point count, and clear or abandon work.
struct FFMeasurementPanel: View {
    @ObservedObject var session: FFMeasurementSession
    let unit: FFLengthUnit

    private var status: String {
        if !session.draft.isEmpty {
            let next = min(session.draft.count + 1, session.kind.pointCount)
            return "Tap point \(next) of \(session.kind.pointCount)"
        }
        if let value = session.latest?.displayText(unit) {
            return value
        }
        return session.kind.pointCount == 2
            ? "Tap two snapped points"
            : "Tap three snapped points"
    }

    var body: some View {
        FFPanel(title: "Measure", subtitle: "Snapped points", trailing: unit.label) {
            HStack(spacing: FFSpace.xxs) {
                chip(.distance)
                chip(.angle)
                chip(.radius)
            }
            HStack(spacing: FFSpace.xxs) {
                chip(.diameter)
                chip(.ringInnerDiameter)
            }

            Text(status)
                .font(FFType.mono)
                .foregroundStyle(FFPalette.textPrimary.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("shell.measure.value")
                .accessibilityLabel(status)

            HStack(spacing: FFSpace.xxs) {
                FFChip(
                    title: "Cancel",
                    accessibilityIdentifier: "shell.measure.cancel"
                ) {
                    session.cancelDraft()
                }
                FFChip(
                    title: "Clear",
                    accessibilityIdentifier: "shell.measure.clear"
                ) {
                    session.clear()
                }
            }
        }
        .frame(width: 320)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shell.measure.card")
    }

    private func chip(_ kind: FFMeasurementKind) -> some View {
        FFChip(
            title: kind.shortLabel,
            systemImage: kind.systemImage,
            isSelected: session.kind == kind,
            accessibilityIdentifier: "shell.measure.kind.\(kind.rawValue)"
        ) {
            session.select(kind)
        }
    }
}
