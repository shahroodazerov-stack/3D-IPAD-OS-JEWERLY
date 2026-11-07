import Foundation
import SwiftUI

/// Marker graphics for the snapping engine. Every candidate is drawn at the
/// screen point the resolver measured, so a marker is never a decoration: it is
/// the projected position the next command would use. The overlay does not take
/// touches; camera and gizmo gestures keep working underneath it.
struct FFSnapOverlay: View {
    let markers: [FFSnapMarker]

    private var best: FFSnapMarker? {
        markers.first(where: \.isBest)
    }

    var body: some View {
        ZStack {
            ForEach(markers) { marker in
                glyph(for: marker)
                    .position(x: marker.screen.x, y: marker.screen.y)
                    .accessibilityElement()
                    .accessibilityIdentifier("snap.marker")
                    .accessibilityLabel("Snap \(marker.label)")
            }

            if let best {
                Text(best.label)
                    .font(FFType.monoSmall)
                    .foregroundStyle(FFPalette.textPrimary.color)
                    .padding(.horizontal, FFSpace.xxs)
                    .padding(.vertical, 2)
                    .background(
                        FFPalette.panel.color.opacity(0.94),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                    .position(x: best.screen.x, y: best.screen.y - 18)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// Distinct silhouettes let a jeweller tell a vertex from a grid point at a
    /// glance; the label names the winner without adding ten text boxes.
    private func glyph(for marker: FFSnapMarker) -> some View {
        Image(systemName: symbol(for: marker.kind))
            .font(.system(size: marker.isBest ? 13 : 10, weight: .bold))
            .foregroundStyle(
                marker.isBest ? FFPalette.accent.color : FFPalette.textSecondary.color
            )
            .frame(width: 18, height: 18)
            .background(
                FFPalette.canvas.color.opacity(marker.isBest ? 0.85 : 0.0),
                in: Circle()
            )
    }

    private func symbol(for kind: FFSnapKind) -> String {
        switch kind {
        case .vertex: return "diamond.fill"
        case .endpoint: return "square.fill"
        case .midpoint: return "triangle.fill"
        case .centre: return "circle.fill"
        case .intersection: return "xmark"
        case .perpendicular: return "l.square"
        case .tangent: return "circle"
        case .onCurve: return "circle.dashed"
        case .angle: return "arrow.up.right"
        case .grid: return "plus"
        }
    }
}
