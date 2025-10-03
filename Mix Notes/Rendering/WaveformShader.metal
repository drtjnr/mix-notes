#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float2 viewportSize;
    float progress;
};

vertex VertexOut waveform_vertex(const VertexIn vertex_in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(vertex_in.position, 0.0, 1.0);
    out.uv = (vertex_in.position + 1.0) * 0.5;
    return out;
}

fragment float4 waveform_fragment(VertexOut in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(1)]]) {
    // Solid dark grey color for the waveform
    return float4(0.4, 0.4, 0.4, 1.0);
} 