
@group(0) @binding(0) var<storage, read> buffer_to_render : array<vec4u>; // change buffer type

const vertex_array = array<vec2f, 3>(
    vec2f(0.0, 0.25),
    vec2f(0.0, 0.0),
    vec2f(2.0, 0.0)
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

@fragment fn fragment(vertex_output: VertexOutput) -> @location(0) vec4f {
    let position = vertex_output.position;
    if (position.x > 1.0 || position.y > 0.125) { discard; }

    let length = f32(arrayLength(&buffer_to_render));
    let index = u32(round(position.x * length));
    let value = f32((buffer_to_render[index].x >> 7) & 0xFFu); // chunk, to see if it's ordered correctly

    return vec4f(value, 0.0, 0.0, 1.0);
}