#include <metal_stdlib>

using namespace metal;

typedef struct {
    float4 position [[position]];
    float2 texcoord;
} vertex_data;

vertex vertex_data basic_vertex(const device packed_float2* vertex_array [[ buffer(0) ]], unsigned int vid [[ vertex_id ]]) {
    float2 texcoords[] = {
        {0, 1},
        {0, 0},
        {1, 1},
        {1, 0}
    };
	vertex_data out = {
		.position = float4(vertex_array[vid], 0.0, 1.0),
		.texcoord = texcoords[vid]
	};
    return out;
}

fragment half4 basic_fragment(vertex_data in [[ stage_in ]], texture2d<float> texture [[ texture(0) ]]) {
    constexpr sampler s(address::clamp_to_zero, filter::nearest);
    return half4(texture.sample(s, in.texcoord));
}
