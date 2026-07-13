const vertex_array = array<vec2f, 3>(
    vec2f(-1.0,  3.0),
    vec2f(-1.0, -1.0),
    vec2f( 3.0, -1.0)
);

struct VertexOutput {
    @builtin(position) position : vec4f
}

@vertex fn vertex(
    @builtin(vertex_index) vertex_index : u32,
) -> VertexOutput {
    return VertexOutput(
        vec4f(vertex_array[vertex_index], 0.0, 1.0)
    );
}

//   0  ,  0                  width  ,    0
//    
//                viewport
//
//  0 , height               width, height

@group(0) @binding(0) var<uniform> viewport : vec2f;
@group(0) @binding(1) var<storage, read_write> buffer_to_render : array<array<u32, 16>>; // change buffer type

@fragment fn fragment(vertex_output: VertexOutput) -> @location(0) vec4f {
    // let position = vec2u(vec2f(vertex_output.position.x, viewport.y - vertex_output.position.y));
    let position = vec2u(vertex_output.position.xy);
    let index = position.x + (position.y >> 4) * u32(viewport.x);
    let buffer_length = arrayLength(&buffer_to_render);
    if (index > buffer_length) { discard; }

    // digit_prefix
    let value = buffer_to_render[index][position.y & 0xFu];

    return vec4f(f32(value >> 8)/255.0, f32(value & 0xFFu)/255.0, f32(position.y & 0xFu)/255.0, 1.0) * 8;
}

// @fragment fn fragment(vertex_output: VertexOutput) -> @location(0) vec4f {
//     // let position = vec2u(vec2f(vertex_output.position.x, viewport.y - vertex_output.position.y));
//     let position = vec2u(vertex_output.position.xy);
//     let index = position.x + position.y * u32(viewport.x);
//     let buffer_length = arrayLength(&buffer_to_render);
//     if (index > buffer_length) { discard; }

//     // digit_prefix
//     let value = buffer_to_render[index].x >> 7;

//     return vec4f(f32(value >> 8)/255.0, f32(value & 0xFFu)/255.0, 1.0, 1.0);
// }