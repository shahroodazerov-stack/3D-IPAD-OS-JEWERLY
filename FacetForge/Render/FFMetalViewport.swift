import Foundation
import MetalKit
import QuartzCore
import simd
import SwiftUI
import UIKit

/// One vertex of the viewport's line list. The memory layout is deliberately
/// shared with the Metal shader below: `SIMD3<Float>` occupies 16 bytes, so
/// `color` starts at byte 16 exactly as it does in MSL.
struct FFLineVertex: Equatable {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

/// Rolling frame statistics for the viewport overlay. The window is one
/// second; the first frame opens the window and the following frames count
/// into it, so 60 frames in one second reports exactly 60 fps.
struct FFFrameStatistics: Equatable, Sendable {
    private(set) var frameCount = 0
    private(set) var averageFPS = 0.0

    private var windowStart: Double?
    private var framesInWindow = 0
    private var lastFrameTime: Double?

    mutating func record(frameAt time: Double) {
        guard time.isFinite else { return }
        if let last = lastFrameTime, time <= last {
            return
        }
        lastFrameTime = time
        frameCount += 1

        guard let start = windowStart else {
            windowStart = time
            framesInWindow = 0
            return
        }

        framesInWindow += 1
        let elapsed = time - start
        guard elapsed >= 1 else { return }

        averageFPS = Double(framesInWindow) / elapsed
        windowStart = time
        framesInWindow = 0
    }
}

/// Deterministic line geometry for the empty-scene viewport. The grid lies in
/// the XZ plane and the three world axes are drawn on top of it.
enum FFViewportGeometry {
    static let defaultExtent = 60.0
    static let defaultSpacing = 5.0

    static let minorColor = SIMD4<Float>(0.30, 0.33, 0.38, 1)
    static let majorColor = SIMD4<Float>(0.44, 0.48, 0.55, 1)
    static let xAxisColor = SIMD4<Float>(0.93, 0.33, 0.30, 1)
    static let yAxisColor = SIMD4<Float>(0.40, 0.88, 0.46, 1)
    static let zAxisColor = SIMD4<Float>(0.32, 0.56, 0.96, 1)

    /// Returns a line-list vertex array. Every pair of vertices is one line.
    static func gridAndAxes(
        extent: Double = defaultExtent,
        spacing: Double = defaultSpacing
    ) -> [FFLineVertex] {
        guard extent.isFinite, spacing.isFinite, extent > 0, spacing > 0 else {
            return []
        }
        let stepCount = Int((extent / spacing).rounded())
        guard stepCount > 0 else { return [] }

        var vertices: [FFLineVertex] = []
        vertices.reserveCapacity(stepCount * 8 + 6)

        for index in -stepCount...stepCount where index != 0 {
            let coordinate = Double(index) * spacing
            let color = index % 5 == 0 ? majorColor : minorColor
            appendLine(
                from: Vec3(x: coordinate, y: 0, z: -extent),
                to: Vec3(x: coordinate, y: 0, z: extent),
                color: color,
                into: &vertices
            )
            appendLine(
                from: Vec3(x: -extent, y: 0, z: coordinate),
                to: Vec3(x: extent, y: 0, z: coordinate),
                color: color,
                into: &vertices
            )
        }

        appendLine(
            from: Vec3(x: -extent, y: 0, z: 0),
            to: Vec3(x: extent, y: 0, z: 0),
            color: xAxisColor,
            into: &vertices
        )
        appendLine(
            from: Vec3(x: 0, y: 0, z: 0),
            to: Vec3(x: 0, y: extent, z: 0),
            color: yAxisColor,
            into: &vertices
        )
        appendLine(
            from: Vec3(x: 0, y: 0, z: -extent),
            to: Vec3(x: 0, y: 0, z: extent),
            color: zAxisColor,
            into: &vertices
        )

        return vertices
    }

    private static func appendLine(
        from start: Vec3,
        to end: Vec3,
        color: SIMD4<Float>,
        into vertices: inout [FFLineVertex]
    ) {
        vertices.append(FFLineVertex(
            position: SIMD3<Float>(Float(start.x), Float(start.y), Float(start.z)),
            color: color
        ))
        vertices.append(FFLineVertex(
            position: SIMD3<Float>(Float(end.x), Float(end.y), Float(end.z)),
            color: color
        ))
    }
}

/// A readback used by the offscreen renderer test. Pixels are BGRA8 in sRGB,
/// matching the viewport's `.bgra8Unorm_srgb` color attachment.
struct FFViewportReadback: Equatable {
    let width: Int
    let height: Int
    let pixels: [UInt8]
}

/// Owns the Metal device, the line pipeline and the immutable grid buffer.
///
/// Phase 9 draws only lines, so the renderer uses one buffer and one draw call.
/// The offscreen entry point exists to prove the pipeline actually rasterises
/// grid and axis pixels in CI, not just that the app launched.
final class FFMetalViewportRenderer {
    static let preferredSampleCount = 4
    static let colorPixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    static let depthPixelFormat: MTLPixelFormat = .depth32Float
    static let clearColor = MTLClearColor(red: 0.055, green: 0.062, blue: 0.078, alpha: 1)

    let device: MTLDevice
    let pixelFormat: MTLPixelFormat
    let sampleCount: Int
    let lineCount: Int

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let vertexBuffer: MTLBuffer
    private(set) var statistics = FFFrameStatistics()
    private(set) var drawCallCount = 0
    private(set) var lastCommandBufferError: String?

    init?(
        device providedDevice: MTLDevice? = MTLCreateSystemDefaultDevice(),
        pixelFormat: MTLPixelFormat = FFMetalViewportRenderer.colorPixelFormat,
        sampleCount: Int = FFMetalViewportRenderer.preferredSampleCount
    ) {
        guard let device = providedDevice ?? MTLCreateSystemDefaultDevice() else {
            return nil
        }
        guard sampleCount > 0, sampleCount <= 8,
              device.supportsTextureSampleCount(sampleCount)
        else { return nil }
        guard let commandQueue = device.makeCommandQueue() else { return nil }

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        } catch {
            return nil
        }
        guard let vertexFunction = library.makeFunction(name: "ff_vertex"),
              let fragmentFunction = library.makeFunction(name: "ff_fragment")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "FacetForge viewport lines"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.rasterSampleCount = sampleCount
        descriptor.depthAttachmentPixelFormat = Self.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        let pipelineState: MTLRenderPipelineState
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.label = "FacetForge viewport depth"
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            return nil
        }

        let vertices = FFViewportGeometry.gridAndAxes()
        guard !vertices.isEmpty else { return nil }
        let buffer: MTLBuffer? = vertices.withUnsafeBytes { rawBuffer -> MTLBuffer? in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            return device.makeBuffer(
                bytes: baseAddress,
                length: rawBuffer.count,
                options: .storageModeShared
            )
        }
        guard let vertexBuffer = buffer else { return nil }

        self.device = device
        self.pixelFormat = pixelFormat
        self.sampleCount = sampleCount
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.depthState = depthState
        self.vertexBuffer = vertexBuffer
        self.lineCount = vertices.count / 2
    }

    /// Draws the grid and axes into an `MTKView`. The caller owns the camera
    /// because Phase 10 will animate it from gestures.
    func draw(in view: MTKView, camera: FFCamera, at time: Double = CACurrentMediaTime()) {
        let width = max(1, view.drawableSize.width)
        let height = max(1, view.drawableSize.height)
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = Self.clearColor
        // Keep MTKView's own store action: with MSAA it is a multisample
        // resolve into the drawable, and overwriting it with `.store` would
        // leave the drawable unresolved.
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1

        encode(
            pass: pass,
            commandBuffer: commandBuffer,
            camera: camera,
            aspect: Double(width / height)
        )
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [weak self] buffer in
            if let error = buffer.error {
                self?.lastCommandBufferError = error.localizedDescription
            }
        }
        commandBuffer.commit()

        drawCallCount += 1
        statistics.record(frameAt: time)
    }

    /// Renders to textures and reads the resolved sRGB pixels back. This is the
    /// only way a hosted unit test can prove the shader and pipeline produce
    /// visible geometry rather than merely compiling.
    func renderOffscreen(
        width: Int,
        height: Int,
        camera: FFCamera
    ) -> FFViewportReadback? {
        guard width > 0, height > 0, width <= 4_096, height <= 4_096 else {
            return nil
        }

        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        colorDescriptor.usage = .renderTarget
        colorDescriptor.storageMode = .private
        guard let resolveTexture = device.makeTexture(descriptor: colorDescriptor) else {
            return nil
        }

        let multisampleDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        multisampleDescriptor.textureType = .type2DMultisample
        multisampleDescriptor.sampleCount = sampleCount
        multisampleDescriptor.usage = .renderTarget
        multisampleDescriptor.storageMode = .private
        guard let multisampleTexture = device.makeTexture(descriptor: multisampleDescriptor) else {
            return nil
        }

        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.depthPixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDescriptor.textureType = .type2DMultisample
        depthDescriptor.sampleCount = sampleCount
        depthDescriptor.usage = .renderTarget
        depthDescriptor.storageMode = .private
        guard let depthTexture = device.makeTexture(descriptor: depthDescriptor) else {
            return nil
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = multisampleTexture
        pass.colorAttachments[0].resolveTexture = resolveTexture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .multisampleResolve
        pass.colorAttachments[0].clearColor = Self.clearColor
        pass.depthAttachment.texture = depthTexture
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        encode(
            pass: pass,
            commandBuffer: commandBuffer,
            camera: camera,
            aspect: Double(width) / Double(height)
        )

        let bytesPerRow = width * 4
        guard let readbackBuffer = device.makeBuffer(
            length: bytesPerRow * height,
            options: .storageModeShared
        ), let blit = commandBuffer.makeBlitCommandEncoder()
        else { return nil }

        blit.copy(
            from: resolveTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: readbackBuffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: bytesPerRow * height
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            lastCommandBufferError = error.localizedDescription
            return nil
        }

        let count = bytesPerRow * height
        let pointer = readbackBuffer.contents().bindMemory(to: UInt8.self, capacity: count)
        let pixels = Array(UnsafeBufferPointer(start: pointer, count: count))
        return FFViewportReadback(width: width, height: height, pixels: pixels)
    }

    private func encode(
        pass: MTLRenderPassDescriptor,
        commandBuffer: MTLCommandBuffer,
        camera: FFCamera,
        aspect: Double
    ) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }
        encoder.label = "FacetForge grid and axes"
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        var matrix = camera.viewProjectionMatrix(aspect: aspect).metalMatrix
        encoder.setVertexBytes(
            &matrix,
            length: MemoryLayout<simd_float4x4>.stride,
            index: 1
        )
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lineCount * 2)
        encoder.endEncoding()
    }

    /// The shader is kept inline so the hand-authored Xcode project does not
    /// need a `.metal` build rule. It is compiled once per renderer instance.
    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct FFVertex {
        float3 position;
        float4 color;
    };

    struct FFVaryings {
        float4 position [[position]];
        float4 color;
    };

    vertex FFVaryings ff_vertex(
        uint vertexID [[vertex_id]],
        device const FFVertex *vertices [[buffer(0)]],
        constant float4x4 &mvp [[buffer(1)]]
    ) {
        FFVaryings out;
        FFVertex value = vertices[vertexID];
        out.position = mvp * float4(value.position, 1.0);
        out.color = value.color;
        return out;
    }

    fragment float4 ff_fragment(FFVaryings in [[stage_in]]) {
        return in.color;
    }
    """
}

private extension Mat4 {
    /// `Mat4` is row-major; Metal expects column-major matrix columns. Each
    /// column here is one column of the kernel matrix, not a row.
    var metalMatrix: simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(Float(m00), Float(m10), Float(m20), Float(m30)),
            SIMD4<Float>(Float(m01), Float(m11), Float(m21), Float(m31)),
            SIMD4<Float>(Float(m02), Float(m12), Float(m22), Float(m32)),
            SIMD4<Float>(Float(m03), Float(m13), Float(m23), Float(m33))
        ))
    }
}

/// SwiftUI host for the Metal viewport. It rebuilds no renderer on every
/// camera update: the coordinator owns the device pipeline and only swaps the
/// camera value.
struct FFMetalViewportView: UIViewRepresentable {
    var camera: FFCamera
    var onStatistics: (FFFrameStatistics) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(camera: camera, onStatistics: onStatistics)
    }

    func makeUIView(context: Context) -> UIView {
        guard let renderer = FFMetalViewportRenderer() else {
            return Self.makeUnavailableView()
        }

        let view = MTKView(frame: .zero, device: renderer.device)
        view.colorPixelFormat = renderer.pixelFormat
        view.depthStencilPixelFormat = FFMetalViewportRenderer.depthPixelFormat
        view.sampleCount = renderer.sampleCount
        view.clearColor = FFMetalViewportRenderer.clearColor
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.autoResizeDrawable = true
        view.framebufferOnly = true
        view.delegate = context.coordinator
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "shell.viewport.metal"
        view.accessibilityLabel = "3D Metal viewport"
        view.accessibilityValue = "Grid and world axes"
        context.coordinator.attach(renderer: renderer, view: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.camera = camera
        context.coordinator.onStatistics = onStatistics
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    private static func makeUnavailableView() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(
            red: 0.055,
            green: 0.062,
            blue: 0.078,
            alpha: 1
        )

        let label = UILabel()
        label.text = "Metal viewport unavailable on this host"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .footnote)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "shell.viewport.metalUnavailable"
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 0.8),
        ])
        return container
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var camera: FFCamera
        var onStatistics: (FFFrameStatistics) -> Void

        private var renderer: FFMetalViewportRenderer?
        private weak var metalView: MTKView?
        private var lastReportTime: Double = 0

        init(camera: FFCamera, onStatistics: @escaping (FFFrameStatistics) -> Void) {
            self.camera = camera
            self.onStatistics = onStatistics
        }

        func attach(renderer: FFMetalViewportRenderer, view: MTKView) {
            self.renderer = renderer
            self.metalView = view
        }

        func detach() {
            metalView?.delegate = nil
            metalView = nil
            renderer = nil
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // MTKView recreates its drawable and multisample texture; the
            // renderer reads `drawableSize` every frame, so no extra work.
        }

        func draw(in view: MTKView) {
            guard let renderer else { return }
            let now = CACurrentMediaTime()
            renderer.draw(in: view, camera: camera, at: now)

            guard now - lastReportTime >= 0.5 else { return }
            lastReportTime = now
            let statistics = renderer.statistics
            DispatchQueue.main.async { [weak self] in
                self?.onStatistics(statistics)
            }
        }
    }
}
