import Foundation

/// How a viewport draws the scene. The mode is a document value: it is saved
/// with the scene so reopening a document restores the drawing the jeweller
/// left, and each viewport keeps its own so a shaded Perspective can sit beside
/// a technical Top.
enum FFDisplayMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case shaded
    case shadedEdges
    case clay
    case wireframe
    case technical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shaded: "Shaded"
        case .shadedEdges: "Shaded with edges"
        case .clay: "Clay"
        case .wireframe: "Wireframe"
        case .technical: "Technical"
        }
    }

    /// The compact form the per-viewport chip prints.
    var shortLabel: String {
        switch self {
        case .shaded: "Shaded"
        case .shadedEdges: "Edges"
        case .clay: "Clay"
        case .wireframe: "Wire"
        case .technical: "Technical"
        }
    }

    var systemImage: String {
        switch self {
        case .shaded: "circle.lefthalf.filled"
        case .shadedEdges: "square.on.square"
        case .clay: "circle.dotted"
        case .wireframe: "grid"
        case .technical: "ruler"
        }
    }

    /// Tapping the chip advances to the next mode, wrapping at the end.
    var next: FFDisplayMode {
        let all = FFDisplayMode.allCases
        guard let index = all.firstIndex(of: self) else { return .shaded }
        return all[(index + 1) % all.count]
    }

    /// The shaded face pass. Wireframe is the only mode with no faces.
    var drawsFaces: Bool { self != .wireframe }

    /// The overlay edge pass. Clay is deliberately clean; technical needs its
    /// line work to read as a drawing.
    var drawsEdges: Bool {
        switch self {
        case .shadedEdges, .wireframe, .technical: true
        case .shaded, .clay: false
        }
    }

    /// Reference geometry is a modelling aid, not part of a wireframe or a
    /// technical drawing.
    var showsGrid: Bool { self != .wireframe && self != .technical }
    var showsShadow: Bool { self != .wireframe && self != .technical }

    var background: FFRGBA {
        switch self {
        case .technical: FFRGBA(red: 0.90, green: 0.91, blue: 0.92)
        case .shaded, .shadedEdges, .clay, .wireframe:
            FFRGBA(red: 0.055, green: 0.062, blue: 0.078)
        }
    }

    var edgeColor: FFRGBA {
        switch self {
        case .wireframe: FFRGBA(red: 0.72, green: 0.78, blue: 0.82)
        case .technical: FFRGBA(red: 0.12, green: 0.13, blue: 0.15)
        // Edges are darker than the gold but lighter than the studio void: a
        // line the same value as the background erases the object's silhouette
        // on a dense mesh, which is every mesh the bench sample ships.
        case .shadedEdges: FFRGBA(red: 0.09, green: 0.095, blue: 0.11)
        case .shaded, .clay: FFRGBA(red: 0.09, green: 0.095, blue: 0.11)
        }
    }

    /// Wireframe is the one mode whose line work is coloured by the layer a
    /// node draws on, so two layers stay distinguishable without changing the
    /// shading or the material. Every other mode keeps its own edge colour.
    var usesLayerColor: Bool { self == .wireframe }

    func strokeColor(for node: FFRenderNode) -> FFRGBA {
        usesLayerColor ? node.layerColor : edgeColor
    }

    /// Modes that replace the document's materials with a single working
    /// material. This is the material override the display-mode row names; the
    /// document's own materials are untouched and return in Shaded.
    var materialOverride: FFRenderMaterial? {
        switch self {
        case .clay:
            FFRenderMaterial(
                baseColor: FFRGBA(red: 0.62, green: 0.60, blue: 0.57),
                metallic: 0,
                roughness: 0.92
            )
        case .technical:
            FFRenderMaterial(
                baseColor: FFRGBA(red: 0.72, green: 0.75, blue: 0.78),
                metallic: 0,
                roughness: 0.90
            )
        case .shaded, .shadedEdges, .wireframe:
            nil
        }
    }

    /// Passed to the shader in `material.w`. The shader only branches for the
    /// flat technical look; every other mode uses the same PBR-lite path.
    var shaderCode: Float {
        switch self {
        case .shaded: 0
        case .shadedEdges: 1
        case .clay: 2
        case .wireframe: 3
        case .technical: 4
        }
    }
}
