import Combine
import Foundation

/// The owner of the editing document and of everything the viewport draws.
///
/// Phases 13–17 grew scene, selection and visibility state inside the shell.
/// The display-mode row makes the mode part of the saved document, so this is
/// the phase that gives that state a real owner: the session holds the
/// `FFDocumentSession`, derives the renderable scene from the document's node
/// tree, and owns selection, the per-viewport display modes and the document's
/// layers. Layer membership, visibility, lock, colour and the current layer are
/// document state with this one owner; the shell keeps only layout and input.
final class FFEditorSession: ObservableObject {
    /// The renderable scene derived from the document. Rebuilt on load and on
    /// any structural edit; the node IDs are the document's node IDs.
    @Published private(set) var scene: FFViewportScene
    /// Selection and visibility for this document. Visibility is deliberately
    /// not persisted yet; the Phase 17 record documents that boundary.
    @Published var selection: FFSelectionState
    /// The saved mode per viewport pane id. Published so a chip redraws as soon
    /// as the document change commits.
    @Published private(set) var displayModes: [String: FFDisplayMode]
    /// Drawing layers. They are document state; this session is their only
    /// owner and the shell only renders them. A node's layer decides whether
    /// it is drawn, whether it can be edited, and its wireframe colour.
    @Published private(set) var layers: [FFLayer]
    @Published private(set) var currentLayerID: UUID?
    /// Where the document was last saved or loaded from. `nil` for a new bench
    /// sample that has never touched disk.
    @Published private(set) var documentURL: URL?

    private(set) var documentSession: FFDocumentSession
    private let store: FFDocumentStore

    /// A new session. With no document argument the bench sample is loaded and
    /// its stone opens selected, which is the state Phase 17's CI asserts.
    init(
        document: FFDocument? = nil,
        documentURL: URL? = nil,
        store: FFDocumentStore = FFDocumentStore()
    ) {
        let sample = FFDocument.benchSample
        let initial = document ?? sample.document
        self.store = store
        self.documentSession = FFDocumentSession(document: initial)
        self.scene = Self.scene(from: initial)
        self.displayModes = initial.displayModes
        self.layers = initial.layers
        self.currentLayerID = initial.currentLayerID
        self.documentURL = documentURL
        self.selection = document == nil
            ? FFSelectionState(selectedIDs: sample.selectedNodeIDs)
            : FFSelectionState()
    }

    var document: FFDocument { documentSession.document }

    func displayMode(for paneID: String) -> FFDisplayMode {
        displayModes[paneID] ?? .shaded
    }

    /// Cycles one viewport's mode. The change goes through the document
    /// session, so it lands in the same save file and the same undo history as
    /// a node edit.
    func cycleDisplayMode(for paneID: String) {
        setDisplayMode(displayMode(for: paneID).next, for: paneID)
    }

    @discardableResult
    func setDisplayMode(_ mode: FFDisplayMode, for paneID: String) -> Bool {
        guard displayMode(for: paneID) != mode else { return false }
        let changed = documentSession.perform(
            "Display mode \(mode.label)",
            coalescingKey: "display-mode-\(paneID)"
        ) { document in
            document.displayModes[paneID] = mode
        }
        guard changed else { return false }
        displayModes = documentSession.document.displayModes
        return true
    }

    // MARK: - Layers

    func layer(withID id: UUID?) -> FFLayer? {
        documentSession.document.layer(withID: id)
    }

    var currentLayer: FFLayer? { layer(withID: currentLayerID) }

    func nodeCount(inLayer id: UUID) -> Int {
        documentSession.document.nodeIDs(inLayer: id).count
    }

    /// The nodes whose layer is locked. The shell uses this to keep the gizmo
    /// off an uneditable node; the session itself refuses every edit command
    /// that would change one.
    var lockedNodeIDs: Set<UUID> {
        var ids: Set<UUID> = []
        for layer in layers where layer.isLocked {
            ids.formUnion(documentSession.document.nodeIDs(inLayer: layer.id))
        }
        return ids
    }

    func isLocked(nodeID: UUID) -> Bool {
        documentSession.document.layer(forNodeID: nodeID)?.isLocked ?? false
    }

    @discardableResult
    func addLayer(named name: String? = nil) -> UUID? {
        let index = layers.count
        let layer = FFLayer(
            name: name ?? "Layer \(index + 1)",
            color: FFLayer.palette[index % FFLayer.palette.count]
        )
        let changed = documentSession.perform("Add layer") { document in
            document.layers.append(layer)
            document.currentLayerID = layer.id
        }
        guard changed else { return nil }
        syncLayers()
        return layer.id
    }

    @discardableResult
    func setCurrentLayer(_ id: UUID) -> Bool {
        guard documentSession.document.layer(withID: id) != nil,
              documentSession.document.currentLayerID != id
        else { return false }
        let changed = documentSession.perform(
            "Current layer",
            coalescingKey: "current-layer"
        ) { document in
            document.currentLayerID = id
        }
        guard changed else { return false }
        syncLayers()
        return true
    }

    @discardableResult
    func setLayerVisible(_ id: UUID, isVisible: Bool) -> Bool {
        guard let layer = documentSession.document.layer(withID: id),
              layer.isVisible != isVisible
        else { return false }
        let changed = documentSession.perform("Layer visibility") { document in
            guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
            document.layers[index].isVisible = isVisible
        }
        guard changed else { return false }
        // Visibility is baked into the derived scene, so the rebuild is what
        // makes a hidden layer unpickable rather than merely undrawn.
        syncLayers()
        return true
    }

    @discardableResult
    func setLayerLocked(_ id: UUID, isLocked: Bool) -> Bool {
        guard let layer = documentSession.document.layer(withID: id),
              layer.isLocked != isLocked
        else { return false }
        let changed = documentSession.perform("Layer lock") { document in
            guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
            document.layers[index].isLocked = isLocked
        }
        guard changed else { return false }
        syncLayers()
        return true
    }

    @discardableResult
    func cycleLayerColor(_ id: UUID) -> Bool {
        guard let layer = documentSession.document.layer(withID: id) else { return false }
        let changed = documentSession.perform("Layer colour \(layer.name)") { document in
            guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
            document.layers[index].color = document.layers[index].nextColor
        }
        guard changed else { return false }
        syncLayers()
        return true
    }

    /// Moves the current selection to `layerID`. A locked layer rejects the
    /// edit, and so does a locked source layer: lock is a property of the
    /// objects on the layer, not only of the destination. Returns how many
    /// nodes actually moved.
    @discardableResult
    func assignSelection(to layerID: UUID) -> Int {
        let document = documentSession.document
        guard let target = document.layer(withID: layerID), !target.isLocked else { return 0 }
        let movable = selection.selectedIDs
            .filter { !isLocked(nodeID: $0) }
            .filter { document.node(withID: $0)?.layerID != layerID }
            .sorted { $0.uuidString < $1.uuidString }
        guard !movable.isEmpty else { return 0 }

        var moved = 0
        let changed = documentSession.perform("Assign to \(target.name)") { draft in
            for id in movable where draft.updateNode(withID: id, { $0.layerID = layerID }) {
                moved += 1
            }
        }
        guard changed else { return 0 }
        syncLayers()
        return moved
    }

    /// Selects every node on a visible layer. A hidden layer is unpickable by
    /// the row's acceptance, and selecting it by name must not be a back door.
    @discardableResult
    func selectLayer(_ id: UUID, extend: Bool = false) -> Bool {
        guard let layer = documentSession.document.layer(withID: id), layer.isVisible else {
            return false
        }
        selection.select(documentSession.document.nodeIDs(inLayer: id), extend: extend)
        return true
    }

    private func syncLayers() {
        layers = documentSession.document.layers
        currentLayerID = documentSession.document.currentLayerID
        scene = Self.scene(from: documentSession.document)
    }

    /// Saves to `url`, or to the last known URL. A document that has never been
    /// saved goes to the app's Documents directory.
    func save(to url: URL? = nil) throws {
        let destination = url ?? documentURL ?? Self.defaultDocumentURL
        try store.save(documentSession.document, to: destination)
        documentURL = destination
    }

    func reopen() throws {
        guard let documentURL else { return }
        try reopen(from: documentURL)
    }

    /// Loads a document from disk and replaces the scene, modes and selection.
    /// The undo history is reset: undo must never reach across a reopened file.
    func reopen(from url: URL) throws {
        let loaded = try store.load(from: url)
        documentSession = FFDocumentSession(document: loaded)
        scene = Self.scene(from: loaded)
        displayModes = loaded.displayModes
        layers = loaded.layers
        currentLayerID = loaded.currentLayerID
        documentURL = url
        selection = FFSelectionState.initial(for: scene)
    }

    static var defaultDocumentURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("Untitled.facetforge.json")
    }

    /// Flattens the document's node tree into the flat scene the renderer
    /// consumes. Parent transforms compose into world transforms, and a node
    /// without mesh geometry contributes no drawable but still passes its
    /// transform to its children.
    static func scene(from document: FFDocument) -> FFViewportScene {
        var nodes: [FFRenderNode] = []

        func visit(_ node: FFNode, parent: Mat4) {
            let world = parent * node.transform.matrix
            if case .mesh(let payload)? = node.geometry,
               let mesh = payload.mesh,
               let renderMesh = FFRenderMesh(mesh: mesh) {
                let material = node.materialID
                    .flatMap { document.material(withID: $0) }
                    .map(FFRenderMaterial.init(from:)) ?? .gold
                let layer = document.layer(forNodeID: node.id)
                nodes.append(FFRenderNode(
                    id: node.id,
                    name: node.name,
                    mesh: renderMesh,
                    transform: world,
                    material: material,
                    kind: node.kind ?? .solid,
                    isVisible: node.isVisible && (layer?.isVisible ?? true),
                    layerColor: layer?.color ?? FFRGBA.gold
                ))
            }
            for child in node.children {
                visit(child, parent: world)
            }
        }

        for root in document.rootNodes {
            visit(root, parent: .identity)
        }
        return FFViewportScene(nodes: nodes)
    }
}

extension FFRenderMaterial {
    /// The document stores a richer material; the renderer only needs the
    /// surface colour and the two scalar terms.
    init(from material: FFMaterial) {
        self.init(
            baseColor: material.baseColor,
            metallic: material.metallic,
            roughness: material.roughness
        )
    }
}
