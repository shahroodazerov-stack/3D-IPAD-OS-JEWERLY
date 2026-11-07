import Foundation
import SwiftUI

/// The four width bands the shell is designed around. Phase 4 names these
/// explicitly so the layout contract is testable without a rendered window.
enum FFBreakpoint: String, CaseIterable, Sendable {
    case compact
    case medium
    case regular
    case wide

    init(width: CGFloat) {
        if width >= 1366 {
            self = .wide
        } else if width >= 1024 {
            self = .regular
        } else if width >= 820 {
            self = .medium
        } else {
            self = .compact
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .compact: 0
        case .medium: 820
        case .regular: 1024
        case .wide: 1366
        }
    }

    var label: String {
        switch self {
        case .compact: "Compact"
        case .medium: "Medium"
        case .regular: "Regular"
        case .wide: "Wide"
        }
    }
}

/// Computed geometry for the three-zone workspace. The values are pure data,
/// so a unit test can freeze them as a layout snapshot and the UI test can
/// verify what the rendered shell actually produced.
struct FFShellMetrics: Equatable {
    let width: CGFloat
    let breakpoint: FFBreakpoint
    let toolsWidth: CGFloat
    let inspectorWidth: CGFloat
    let toolsCollapsed: Bool
    let inspectorCollapsed: Bool

    var viewportWidth: CGFloat {
        max(0, width - toolsWidth - inspectorWidth)
    }

    var isCompact: Bool {
        breakpoint == .compact
    }

    /// The five widths the Phase 4 UI test drives the shell through. They cover
    /// every breakpoint and both sides of the first threshold.
    static let testWidths: [CGFloat] = [640, 700, 820, 1024, 1366]

    static func calculate(
        width: CGFloat,
        toolsCollapsed: Bool = false,
        inspectorCollapsed: Bool = false
    ) -> FFShellMetrics {
        let safeWidth = max(0, width)
        let breakpoint = FFBreakpoint(width: safeWidth)

        let toolColumn: CGFloat
        let inspectorColumn: CGFloat
        switch breakpoint {
        case .wide:
            toolColumn = 88
            inspectorColumn = 320
        case .regular:
            toolColumn = 80
            inspectorColumn = 288
        case .medium:
            toolColumn = 72
            inspectorColumn = 240
        case .compact:
            toolColumn = 56
            inspectorColumn = 208
        }

        let visibleTools = toolsCollapsed ? 0 : toolColumn
        // Never let the inspector squeeze the viewport below 200 pt. At the
        // 640 pt minimum this cannot trigger; it is the guard for a scene that
        // is resized before the size restriction is applied.
        let availableForInspector = max(0, safeWidth - visibleTools - 200)
        let visibleInspector = inspectorCollapsed ? 0 : min(inspectorColumn, availableForInspector)

        return FFShellMetrics(
            width: safeWidth,
            breakpoint: breakpoint,
            toolsWidth: visibleTools,
            inspectorWidth: visibleInspector,
            toolsCollapsed: toolsCollapsed,
            inspectorCollapsed: inspectorCollapsed
        )
    }
}

/// The deliberate Phase 13 viewport layout. Fresh documents open in a single
/// maximised Perspective; four-up is a preset one chip away, not the default.
/// Keeping the panes as value data lets the unit test freeze the choice and the
/// UI test assert the rendered frames against it.
enum FFViewportLayout: String, CaseIterable, Identifiable, Sendable, Equatable {
    case single
    case fourUp

    static let defaultLayout = FFViewportLayout.single

    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: "1-up"
        case .fourUp: "4-up"
        }
    }

    var accessibilityIdentifier: String { "shell.viewport.layout.\(rawValue)" }

    var panes: [FFViewportPanePlan] {
        switch self {
        case .single:
            [
                FFViewportPanePlan(
                    id: "perspective",
                    title: "Perspective",
                    namedView: .iso,
                    projection: .perspective
                ),
            ]
        case .fourUp:
            [
                FFViewportPanePlan(
                    id: "perspective",
                    title: "Perspective",
                    namedView: .iso,
                    projection: .perspective
                ),
                FFViewportPanePlan(
                    id: "top",
                    title: "Top",
                    namedView: .top,
                    projection: .orthographic
                ),
                FFViewportPanePlan(
                    id: "front",
                    title: "Front",
                    namedView: .front,
                    projection: .orthographic
                ),
                FFViewportPanePlan(
                    id: "right",
                    title: "Right",
                    namedView: .right,
                    projection: .orthographic
                ),
            ]
        }
    }

    var initialCameras: [String: FFCamera] {
        Dictionary(uniqueKeysWithValues: panes.map { ($0.id, $0.initialCamera) })
    }
}

/// One pane of a layout. The initial camera is derived from the named view and
/// projection only; framing stays user-controlled once the pane is live.
struct FFViewportPanePlan: Identifiable, Sendable {
    let id: String
    let title: String
    let namedView: FFNamedView?
    let projection: FFProjectionMode

    var accessibilityIdentifier: String { "shell.viewport.pane.\(id)" }

    var initialCamera: FFCamera {
        var camera = FFCamera.standard
        camera.setProjection(projection)
        if let namedView {
            camera.apply(namedView)
        }
        return camera
    }
}

private struct FFTool: Identifiable {
    let id: String
    let systemImage: String
    let label: String
}

/// The Phase 4 workspace. It is deliberately driven by its container width,
/// not by `horizontalSizeClass`, so Stage Manager resizes are continuous and
/// the layout laboratory can render any width without a second window.
struct FFAppShell: View {
    /// When set, the shell lays itself out at this width instead of the host
    /// width. The layout laboratory uses it; the app leaves it nil.
    var fixedWidth: CGFloat? = nil
    var onOpenGallery: () -> Void = {}

    @State private var selectedTool = "select"
    @State private var toolsCollapsed = false
    @State private var inspectorCollapsed = false
    @State private var bandWidth = "18.00"
    @State private var frameStatistics = FFFrameStatistics()
    @State private var camera = FFCamera.standard
    @State private var namedView: FFNamedView? = .iso
    @State private var lengthUnit: FFLengthUnit = .millimetres

    private let tools: [FFTool] = [
        FFTool(id: "select", systemImage: "cursorarrow", label: "Select"),
        FFTool(id: "sketch", systemImage: "scribble", label: "Sketch"),
        FFTool(id: "gem", systemImage: "diamond", label: "Gem"),
        FFTool(id: "measure", systemImage: "ruler", label: "Measure"),
        FFTool(id: "render", systemImage: "camera", label: "Render"),
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = fixedWidth ?? proxy.size.width
            let metrics = FFShellMetrics.calculate(
                width: width,
                toolsCollapsed: toolsCollapsed,
                inspectorCollapsed: inspectorCollapsed
            )

            VStack(spacing: 0) {
                FFAppBar(width: width, onOpenGallery: onOpenGallery)

                HStack(spacing: 0) {
                    if !toolsCollapsed {
                        FFToolRail(
                            tools: tools,
                            selectedTool: $selectedTool,
                            onCollapse: { toolsCollapsed = true }
                        )
                        .frame(width: metrics.toolsWidth)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("shell.tools")
                    }

                    FFViewport(
                        selectedTool: selectedTool,
                        toolsCollapsed: toolsCollapsed,
                        inspectorCollapsed: inspectorCollapsed,
                        frameStatistics: frameStatistics,
                        camera: $camera,
                        namedView: $namedView,
                        onFrameStatistics: { frameStatistics = $0 },
                        onShowTools: { toolsCollapsed = false },
                        onShowInspector: { inspectorCollapsed = false }
                    )
                    .frame(width: metrics.viewportWidth)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("shell.viewport")

                    if !inspectorCollapsed {
                        FFInspector(
                            bandWidth: $bandWidth,
                            lengthUnit: $lengthUnit,
                            onCollapse: { inspectorCollapsed = true }
                        )
                        .frame(width: metrics.inspectorWidth)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("shell.inspector")
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: width, height: proxy.size.height)
            .background(FFPalette.canvas.color)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shell")
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - App bar

private struct FFAppBar: View {
    let width: CGFloat
    let onOpenGallery: () -> Void

    private var isCompact: Bool {
        width < 820
    }

    var body: some View {
        HStack(spacing: FFSpace.sm) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 21, weight: .light))
                .foregroundStyle(FFPalette.accent.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(AppIdentity.displayName)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(FFPalette.textPrimary.color)

                if !isCompact {
                    Text(AppIdentity.tagline)
                        .font(FFType.caption)
                        .foregroundStyle(FFPalette.textTertiary.color)
                }
            }

            Spacer(minLength: FFSpace.xs)

            if !isCompact {
                Text("Untitled ring")
                    .font(FFType.monoSmall)
                    .foregroundStyle(FFPalette.textSecondary.color)
            }

            Button(action: onOpenGallery) {
                HStack(spacing: FFSpace.xxs) {
                    Image(systemName: "square.grid.2x2")
                    if !isCompact {
                        Text("Components")
                    }
                }
                .font(FFType.caption)
                .foregroundStyle(FFPalette.textSecondary.color)
                .frame(width: isCompact ? 44 : 116, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(FFPressStyle())
            .accessibilityIdentifier("shell.openGallery")
            .accessibilityLabel("Open component gallery")

            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FFPalette.textSecondary.color)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(FFPressStyle())
            .accessibilityLabel("Export")
        }
        .padding(.horizontal, FFSpace.sm)
        .frame(minHeight: 56)
        .background(FFPalette.panel.color)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FFPalette.separator.color)
                .frame(height: 1)
        }
    }
}

// MARK: - Tools

private struct FFToolRail: View {
    let tools: [FFTool]
    @Binding var selectedTool: String
    let onCollapse: () -> Void

    var body: some View {
        VStack(spacing: FFSpace.xxs) {
            ForEach(tools) { tool in
                Button {
                    selectedTool = tool.id
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(
                            selectedTool == tool.id
                                ? FFPalette.onAccent.color
                                : FFPalette.textSecondary.color
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            selectedTool == tool.id ? FFPalette.accent.color : Color.clear,
                            in: RoundedRectangle(cornerRadius: FFRadius.sm, style: .continuous)
                        )
                }
                .buttonStyle(FFPressStyle())
                .accessibilityIdentifier("shell.tool.\(tool.id)")
                .accessibilityLabel(tool.label)
                .accessibilityAddTraits(selectedTool == tool.id ? .isSelected : [])
            }

            Spacer(minLength: FFSpace.xs)

            Button(action: onCollapse) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FFPalette.textTertiary.color)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(FFPressStyle())
            .accessibilityLabel("Hide tools")
        }
        .padding(.vertical, FFSpace.xs)
        .frame(maxHeight: .infinity)
        .background(FFPalette.panel.color)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(FFPalette.separator.color)
                .frame(width: 1)
        }
    }
}

// MARK: - Viewport

private struct FFViewport: View {
    let selectedTool: String
    let toolsCollapsed: Bool
    let inspectorCollapsed: Bool
    let frameStatistics: FFFrameStatistics
    @Binding var camera: FFCamera
    @Binding var namedView: FFNamedView?
    let onFrameStatistics: (FFFrameStatistics) -> Void
    let onShowTools: () -> Void
    let onShowInspector: () -> Void
    @State private var viewportSize = CGSize(width: 800, height: 600)
    @State private var layout: FFViewportLayout = .defaultLayout
    @State private var fourUpCameras: [String: FFCamera] = [:]

    private var scaleBarPlan: FFScaleBarPlan? {
        guard let units = camera.worldUnitsPerPoint(
            viewport: Vec2(x: viewportSize.width, y: viewportSize.height)
        ) else { return nil }
        return FFScaleBar.plan(millimetresPerPoint: units)
    }

    private var fpsLabel: String {
        guard frameStatistics.averageFPS > 0 else { return "starting" }
        return String(format: "%.0f fps", frameStatistics.averageFPS)
    }

    private var cameraLabel: String {
        let prefix = namedView.map { "\($0.label) · " } ?? "Free · "
        return prefix + camera.summary
    }

    var body: some View {
        ZStack {
            FFPalette.canvas.color

            viewportSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: FFSpace.sm) {
                    FFToolbar(items: [
                        FFToolbarItem(id: "shaded", systemImage: "circle.lefthalf.filled", label: "Shaded", isSelected: true),
                        FFToolbarItem(id: "edges", systemImage: "square.on.square", label: "Shaded with edges"),
                        FFToolbarItem(id: "clay", systemImage: "circle.dotted", label: "Clay"),
                        FFToolbarItem(id: "wire", systemImage: "grid", label: "Wireframe"),
                    ])

                    Spacer(minLength: 0)

                    Text(selectedTool.uppercased())
                        .font(FFType.monoSmall)
                        .foregroundStyle(FFPalette.textTertiary.color)
                        .padding(.top, FFSpace.sm)
                        .accessibilityIdentifier("shell.viewport.toolName")
                }
                .padding(FFSpace.sm)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpace.xxs) {
                        ForEach(FFViewportLayout.allCases) { option in
                            FFChip(
                                title: option.label,
                                isSelected: layout == option,
                                accessibilityIdentifier: option.accessibilityIdentifier
                            ) {
                                layout = option
                            }
                        }

                        if layout == .single {
                            ForEach([FFNamedView.iso, .front, .top]) { view in
                                FFChip(
                                    title: view.shortLabel,
                                    isSelected: namedView == view,
                                    accessibilityIdentifier: "shell.viewport.namedView.\(view.rawValue)"
                                ) {
                                    camera.apply(view)
                                    namedView = view
                                }
                            }

                            FFChip(
                                title: camera.projection.label,
                                systemImage: "cube.transparent",
                                accessibilityIdentifier: "shell.viewport.projection"
                            ) {
                                camera.setProjection(
                                    camera.projection == .perspective ? .orthographic : .perspective
                                )
                            }

                            FFChip(
                                title: "Frame",
                                systemImage: "viewfinder",
                                accessibilityIdentifier: "shell.viewport.frame"
                            ) {
                                FFCameraNavigation.frameAll(&camera)
                                namedView = nil
                            }
                        }
                    }
                    .padding(.horizontal, FFSpace.sm)
                }
                .scrollClipDisabled()

                Spacer(minLength: FFSpace.sm)

                HStack(alignment: .bottom, spacing: FFSpace.xs) {
                    VStack(alignment: .leading, spacing: FFSpace.xxs) {
                        if layout == .single, let plan = scaleBarPlan {
                            HStack(spacing: FFSpace.xxs) {
                                Rectangle()
                                    .fill(FFPalette.textSecondary.color)
                                    .frame(width: CGFloat(plan.pixelWidth), height: 2)
                                Text(plan.label)
                                    .font(FFType.monoSmall)
                                    .foregroundStyle(FFPalette.textTertiary.color)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("shell.viewport.scaleBar")
                            .accessibilityLabel("Scale bar, \(plan.label)")
                        }

                        HStack(spacing: FFSpace.xxs) {
                            Circle()
                                .fill(FFPalette.success.color)
                                .frame(width: 6, height: 6)
                            Text(layout == .single ? cameraLabel : "Four-up · Perspective / Top / Front / Right")
                                .font(FFType.monoSmall)
                                .foregroundStyle(FFPalette.textTertiary.color)
                                .lineLimit(1)
                                .accessibilityIdentifier("shell.viewport.camera")
                                .accessibilityLabel(layout == .single ? cameraLabel : "Four-up layout with Perspective, Top, Front and Right panes")

                            Text("\(fpsLabel) · \(layout == .single ? camera.projection.label.lowercased() : "four-up")")
                                .font(FFType.monoSmall)
                                .foregroundStyle(FFPalette.textTertiary.color)
                                .accessibilityIdentifier("shell.viewport.fps")
                                .accessibilityLabel("Metal viewport, grid and world axes, \(fpsLabel)")

                            // The layout chips above already show the current layout
                            // with their selected state. A duplicate label here
                            // overflowed the 749 pt viewport and printed on top of
                            // the fps readout in the Phase 13 snapshot.
                        }
                    }

                    Spacer(minLength: 0)

                    if toolsCollapsed {
                        shellToggle(systemImage: "sidebar.leading", label: "Show tools", action: onShowTools)
                    }
                    if inspectorCollapsed {
                        shellToggle(systemImage: "sidebar.trailing", label: "Show inspector", action: onShowInspector)
                    }
                }
                .padding(FFSpace.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            viewportSize = size
        }
        .clipped()
    }

    @ViewBuilder
    private var viewportSurface: some View {
        switch layout {
        case .single:
            if let pane = FFViewportLayout.single.panes.first {
                FFViewportPane(
                    plan: pane,
                    camera: $camera,
                    scene: .jewelleryDemo,
                    metalIdentifier: "shell.viewport.metal",
                    onCameraChange: { updated in
                        camera = updated
                        namedView = FFCameraNavigation.namedView(for: updated)
                    },
                    onStatistics: onFrameStatistics
                )
            }
        case .fourUp:
            fourUpGrid
        }
    }

    private var fourUpGrid: some View {
        let panes = FFViewportLayout.fourUp.panes
        return GeometryReader { proxy in
            let gap: CGFloat = 1
            let paneWidth = max(1, (proxy.size.width - gap) / 2)
            let paneHeight = max(1, (proxy.size.height - gap) / 2)

            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    fourUpPane(panes[0])
                        .frame(width: paneWidth, height: paneHeight)
                    fourUpPane(panes[1])
                        .frame(width: paneWidth, height: paneHeight)
                }
                HStack(spacing: gap) {
                    fourUpPane(panes[2])
                        .frame(width: paneWidth, height: paneHeight)
                    fourUpPane(panes[3])
                        .frame(width: paneWidth, height: paneHeight)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // The single pane is a UIView host and fills the whole viewport element.
        // A GeometryReader is safe-area aware, so on iPad it stopped 20 pt short
        // of the bottom home-indicator inset and the preset was not a true half
        // split. Ignoring the container inset makes both layouts fill the same
        // rectangle the acceptance test measures.
        .ignoresSafeArea(.container, edges: .bottom)
        .background(FFPalette.separator.color)
    }

    private func fourUpPane(_ pane: FFViewportPanePlan) -> some View {
        FFViewportPane(
            plan: pane,
            camera: fourUpBinding(for: pane),
            scene: .jewelleryDemo,
            metalIdentifier: "shell.viewport.metal.\(pane.id)",
            onCameraChange: { updated in
                fourUpCameras[pane.id] = updated
            },
            onStatistics: onFrameStatistics
        )
    }

    private func fourUpBinding(for pane: FFViewportPanePlan) -> Binding<FFCamera> {
        Binding(
            get: { fourUpCameras[pane.id] ?? pane.initialCamera },
            set: { fourUpCameras[pane.id] = $0 }
        )
    }

    private func shellToggle(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FFPalette.textSecondary.color)
                .frame(width: 44, height: 44)
                .background(
                    FFPalette.panel.color,
                    in: RoundedRectangle(cornerRadius: FFRadius.sm, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: FFRadius.sm, style: .continuous)
                        .stroke(FFPalette.separator.color, lineWidth: 1)
                }
        }
        .buttonStyle(FFPressStyle())
        .accessibilityLabel(label)
    }
}

/// One live viewport pane. The binding is owned by the layout, so the single
/// pane shares the global camera and the four-up panes keep independent ones.
private struct FFViewportPane: View {
    let plan: FFViewportPanePlan
    @Binding var camera: FFCamera
    let scene: FFViewportScene
    let metalIdentifier: String
    let onCameraChange: (FFCamera) -> Void
    let onStatistics: (FFFrameStatistics) -> Void

    @State private var gumball = FFGumballSession()
    @State private var gizmoDragging = false

    /// The four-up panes are camera previews, not editing surfaces. The gizmo
    /// lives in the maximised Perspective pane, the one a document opens in.
    private var showsGumball: Bool { metalIdentifier == "shell.viewport.metal" }

    private var selectedNode: FFRenderNode? {
        scene.nodes.first(where: \.isSelected)
    }

    private var displayScene: FFViewportScene {
        guard let nodeID = gumball.nodeID,
              let index = scene.nodes.firstIndex(where: { $0.id == nodeID })
        else { return scene }
        var copy = scene
        copy.nodes[index].transform = gumball.transform
        return copy
    }

    /// The centre of the selected mesh in world space, used by the Pivot
    /// control. It follows the gizmo transform so the button stays meaningful
    /// after a move.
    private var selectionCentre: Vec3? {
        guard let node = selectedNode, let bounds = node.mesh.bounds else { return nil }
        let local = Vec3(
            x: (bounds.minimum.x + bounds.maximum.x) * 0.5,
            y: (bounds.minimum.y + bounds.maximum.y) * 0.5,
            z: (bounds.minimum.z + bounds.maximum.z) * 0.5
        )
        let transform = node.id == gumball.nodeID ? gumball.transform : node.transform
        let world = transform * Vec4(x: local.x, y: local.y, z: local.z, w: 1)
        guard abs(world.w) > FFMath.eps else { return nil }
        return Vec3(x: world.x / world.w, y: world.y / world.w, z: world.z / world.w)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FFMetalViewportView(
                    camera: camera,
                    scene: displayScene,
                    accessibilityIdentifier: metalIdentifier,
                    allowsCameraGestures: !gizmoDragging,
                    onCameraChange: { updated in
                        camera = updated
                        onCameraChange(updated)
                    },
                    onStatistics: onStatistics
                )

                if showsGumball, gumball.nodeID != nil {
                    FFGumballOverlay(
                        session: $gumball,
                        camera: camera,
                        viewport: proxy.size,
                        selectionCentre: selectionCentre,
                        onDragStateChange: { gizmoDragging = $0 }
                    )
                }
            }
        }
        .onAppear(perform: configureGumball)
        // The pane name is a label, not a floating badge. The bottom HUD already
        // names the layout and every pane, and a badge in the corner printed on
        // top of that HUD in the Phase 13 snapshots at 749 pt.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(plan.accessibilityIdentifier)
        .accessibilityLabel(plan.title)
    }

    private func configureGumball() {
        guard gumball.nodeID == nil, let node = selectedNode else { return }
        gumball.select(nodeID: node.id, transform: node.transform)
    }
}

// MARK: - Inspector

private struct FFInspector: View {
    @Binding var bandWidth: String
    @Binding var lengthUnit: FFLengthUnit
    let onCollapse: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FFSpace.sm) {
                HStack(spacing: FFSpace.xs) {
                    Text("Inspector")
                        .font(FFType.section)
                        .foregroundStyle(FFPalette.textPrimary.color)

                    Spacer(minLength: 0)

                    Button(action: onCollapse) {
                        Image(systemName: "sidebar.trailing")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(FFPalette.textTertiary.color)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(FFPressStyle())
                    .accessibilityLabel("Hide inspector")
                }

                FFPanel(title: "Selection", subtitle: "Solitaire ring", trailing: "18.00 mm") {
                    FFListRow(title: "Band", trailing: "4.1 g")
                    FFListRow(title: "Stone", trailing: "1.00 ct")
                }

                FFPanel(title: "Dimensions", subtitle: "Millimetres") {
                    FFField(label: "Band width", value: $bandWidth, unit: "mm")
                    FFListRow(title: "Wall", trailing: "1.20 mm")

                    HStack(spacing: FFSpace.xxs) {
                        ForEach(FFLengthUnit.allCases) { unit in
                            FFChip(
                                title: unit.label,
                                isSelected: lengthUnit == unit,
                                accessibilityIdentifier: "shell.inspector.unit.\(unit.rawValue)"
                            ) {
                                lengthUnit = unit
                            }
                        }
                    }

                    FFListRow(
                        title: "Converted",
                        trailing: lengthUnit.formatted(millimetres: Double(bandWidth) ?? 18)
                    )
                    FFListRow(
                        title: "Ring size",
                        trailing: String(
                            format: "US %.1f",
                            FFRingSize(innerDiameterMM: 18).usSize
                        )
                    )
                }

                FFPanel(title: "Manufacturing") {
                    FFToast(message: "Wall check passed", kind: .success)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppIdentity.phaseLabel)
                        .foregroundStyle(FFPalette.textTertiary.color)
                    Text(FFSceneSizePolicy.summary)
                        .foregroundStyle(FFPalette.textTertiary.color)
                        .accessibilityIdentifier("shell.scenePolicy")
                }
                .font(FFType.caption)
                .padding(.horizontal, FFSpace.xs)
                .padding(.bottom, FFSpace.sm)
            }
            .padding(FFSpace.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FFPalette.panel.color)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(FFPalette.separator.color)
                .frame(width: 1)
        }
    }
}
