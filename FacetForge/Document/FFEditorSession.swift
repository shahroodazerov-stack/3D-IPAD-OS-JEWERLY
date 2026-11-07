import Combine
import Foundation

/// The owner of the editing document and of everything the viewport draws.
///
/// Phases 13–17 grew scene, selection and visibility state inside the shell.
/// The display-mode row makes the mode part of the saved document, so this is
/// the phase that gives that state a real owner: the session holds the
/// `FFDocumentSession`, derives the renderable scene from the document's node
/// tree, and owns selection and the per-viewport display modes. The shell keeps
/// only layout and input.
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
                nodes.append(FFRenderNode(
                    id: node.id,
                    name: node.name,
                    mesh: renderMesh,
                    transform: world,
                    material: material,
                    kind: node.kind ?? .solid,
                    isVisible: node.isVisible
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
