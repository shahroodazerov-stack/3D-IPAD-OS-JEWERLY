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

            FFMetalViewportView(
                camera: camera,
                onCameraChange: { updated in
                    camera = updated
                    namedView = FFCameraNavigation.namedView(for: updated)
                },
                onStatistics: onFrameStatistics
            )
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
                    .padding(.horizontal, FFSpace.sm)
                }
                .scrollClipDisabled()

                Spacer(minLength: FFSpace.sm)

                HStack(alignment: .bottom, spacing: FFSpace.xs) {
                    HStack(spacing: FFSpace.xxs) {
                        Circle()
                            .fill(FFPalette.success.color)
                            .frame(width: 6, height: 6)
                        Text(cameraLabel)
                            .font(FFType.monoSmall)
                            .foregroundStyle(FFPalette.textTertiary.color)
                            .lineLimit(1)
                            .accessibilityIdentifier("shell.viewport.camera")
                            .accessibilityLabel(cameraLabel)

                        Text("\(fpsLabel) · \(camera.projection.label.lowercased())")
                            .font(FFType.monoSmall)
                            .foregroundStyle(FFPalette.textTertiary.color)
                            .accessibilityIdentifier("shell.viewport.fps")
                            .accessibilityLabel("Metal viewport, grid and world axes, \(fpsLabel)")
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
        .clipped()
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


// MARK: - Inspector

private struct FFInspector: View {
    @Binding var bandWidth: String
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
