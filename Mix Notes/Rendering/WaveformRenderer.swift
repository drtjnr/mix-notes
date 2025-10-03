import Metal
import MetalKit

class WaveformRenderer: ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var vertexBuffer: MTLBuffer
    private var uniformsBuffer: MTLBuffer
    
    private struct Uniforms {
        var viewportSize: SIMD2<Float>
        var progress: Float
    }
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Create vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        
        // Create pipeline state
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "waveform_vertex")!
        let fragmentFunction = library.makeFunction(name: "waveform_fragment")!
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
        
        // Initial empty buffers
        vertexBuffer = device.makeBuffer(length: 0, options: .storageModeShared)!
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)!
    }
    
    func updateWaveform(samples: [Float], size: CGSize, progress: Float) {
        let vertices = createWaveformVertices(samples: samples)
        let bufferSize = vertices.count * MemoryLayout<SIMD2<Float>>.stride
        
        if bufferSize > 0 {
            vertexBuffer = device.makeBuffer(bytes: vertices, length: bufferSize, options: .storageModeShared)!
        } else {
            vertexBuffer = device.makeBuffer(length: 0, options: .storageModeShared)!
        }
        
        var uniforms = Uniforms(viewportSize: SIMD2<Float>(Float(size.width), Float(size.height)), progress: progress)
        uniformsBuffer = device.makeBuffer(bytes: &uniforms, length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)!
    }
    
    private func createWaveformVertices(samples: [Float]) -> [SIMD2<Float>] {
        var vertices: [SIMD2<Float>] = []
        if samples.isEmpty { return vertices }
        
        let step = 2.0 / Float(samples.count - 1)
        
        for (i, sample) in samples.enumerated() {
            let x = -1.0 + Float(i) * step
            vertices.append(SIMD2<Float>(x, -sample))
            vertices.append(SIMD2<Float>(x, sample))
        }
        
        return vertices
    }
    
    func render(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 1)
        
        let vertexCount = vertexBuffer.length / MemoryLayout<SIMD2<Float>>.stride
        if vertexCount > 0 {
            renderEncoder.drawPrimitives(type: .line,
                                       vertexStart: 0,
                                       vertexCount: vertexCount)
        }
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
} 