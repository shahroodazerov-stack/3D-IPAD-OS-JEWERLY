import Foundation

/// A drawing layer. Layers are document state: membership, visibility, lock and
/// colour travel with the save file, and the editor session is their only
/// owner. A node belongs to at most one layer; a node without an assignment
/// draws on the document's first layer.
struct FFLayer: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var color: FFRGBA
    var isVisible: Bool
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        name: String,
        color: FFRGBA,
        isVisible: Bool = true,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.isVisible = isVisible
        self.isLocked = isLocked
    }

    /// The layer a document created before layers decodes into. The id is fixed
    /// so a legacy file gains the same layer every time it is opened.
    static let defaultLayerID = UUID(uuidString: "A11A7E20-0000-4000-8000-000000000020")!

    static var defaultLayer: FFLayer {
        FFLayer(
            id: defaultLayerID,
            name: "Default",
            color: FFRGBA(red: 0.86, green: 0.73, blue: 0.46)
        )
    }

    /// The palette the swatch button cycles. Six steps are enough to tell two
    /// layers apart in wireframe without asking for a colour picker.
    static let palette: [FFRGBA] = [
        FFRGBA(red: 0.86, green: 0.73, blue: 0.46),
        FFRGBA(red: 0.94, green: 0.30, blue: 0.26),
        FFRGBA(red: 0.24, green: 0.80, blue: 0.38),
        FFRGBA(red: 0.34, green: 0.62, blue: 0.96),
        FFRGBA(red: 0.52, green: 0.84, blue: 0.96),
        FFRGBA(red: 0.82, green: 0.44, blue: 0.92)
    ]

    /// The next palette entry after the current colour, so a swatch tap is one
    /// deterministic step rather than a picker sheet.
    var nextColor: FFRGBA {
        let palette = Self.palette
        let index = palette.firstIndex { $0 == color } ?? -1
        return palette[(index + 1) % palette.count]
    }
}

extension FFDocument {
    func layer(withID target: UUID?) -> FFLayer? {
        guard let target else { return nil }
        return layers.first { $0.id == target }
    }

    /// The layer a node draws on. A node with no assignment belongs to the
    /// document's first layer, which is what a legacy file gains on decode.
    func layer(forNodeID nodeID: UUID) -> FFLayer? {
        if let node = node(withID: nodeID), let layer = layer(withID: node.layerID) {
            return layer
        }
        return layers.first
    }

    func nodeIDs(inLayer layerID: UUID) -> [UUID] {
        var ids: [UUID] = []
        // A node without an assignment belongs to the first layer, which is
        // also what `layer(forNodeID:)` answers. Membership and assignment
        // must agree or a legacy node would be drawn on one layer and counted
        // on another.
        let fallback = layers.first?.id
        func visit(_ node: FFNode) {
            if (node.layerID ?? fallback) == layerID { ids.append(node.id) }
            node.children.forEach(visit)
        }
        rootNodes.forEach(visit)
        return ids
    }
}
