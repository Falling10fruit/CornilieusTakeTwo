// type (2^9 = 512)     chunk index 2^16         xPos(2^13)       yPos (16 * 8 pixels divided by 2^13)         rotation 2^13 
//  [ 01010101 0 ]   [ 1010101 01010101 0 ] [ 1010101 | 010101 ]           [ 01 01010101 010 ]              [ 10101 01010101 ] |
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 
// 2^10 -> 1023          2^12 -> 4095

struct EntityData {
    gjk_bounds_dictionary_pointer: u32,
    gjk_bounds_count: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(0) @binding(0) var<storage, read> entity_type_data : array<EntityData>;
@group(0) @binding(1) var<storage, read> entity_nodes : array<vec2f>;
@group(0) @binding(1) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<vec4u>;
@group(0) @binding(6) var<storage, read_write> entities_buffer_meta : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> debug_buffer : f32; // ##DEBUG_TYPE##=
@group(1) @binding(1) var<storage, read>       cosin_lut : array<vec2f>;
@group(1) @binding(2) var<storage, read_write> hilbert_curve : array<u32>;
@group(1) @binding(3) var<storage, read>       world_data : array<u32>;

override phase : u32; // 0 for the first half and 1 for the second

@compute @workgroup_size(256) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let meta_buffer_0 = entities_buffer_meta[local_id * 2];
    let meta_buffer_1 = entities_buffer_meta[local_id * 2 + 1];

    let gjk_checks_count_0 = 
        ((meta_buffer_0.x >> 28) & 0xFu) + 
        ((meta_buffer_0.y >> 28) & 0xFu) + 
        ( // the this_entity gjk boundaries count
            (meta_buffer_0.x >> 31) + 
            (meta_buffer_0.y >> 31) + 
            (meta_buffer_0.z >> 31) + 
            (meta_buffer_0.w >> 31) + 
            (meta_buffer_1.x >> 31) + 
            (meta_buffer_1.y >> 31) + 
            (meta_buffer_1.z >> 31) + 
            (meta_buffer_1.w >> 31)
        );
    let gjk_checks_count_1 = ((meta_buffer_0.z >> 28) & 0xFu) + ((meta_buffer_0.w >> 28) & 0xFu);
    let gjk_checks_count_2 = ((meta_buffer_1.x >> 28) & 0xFu) + ((meta_buffer_1.y >> 28) & 0xFu);
    let gjk_checks_count_3 = ((meta_buffer_1.z >> 28) & 0xFu) + ((meta_buffer_1.w >> 28) & 0xFu);

    let offset = arrayLength(&entities_buffer_1)/2 * (1 - phase);
    entities_buffer_1[offset + local_id] = vec4u(gjk_checks_count_0, gjk_checks_count_1, gjk_checks_count_2, gjk_checks_count_3);
}

fn rotate_node(node : vec2f, cosin : vec2f) -> vec2f {
    return vec2f(
        node.x * cosin.x - node.y * cosin.y,
        node.x * cosin.y + node.y * cosin.x
    );
}

fn cross_2d(vec_0 : vec2f, vec_1 : vec2f) -> f32 {
    return vec_0.x * vec_1.y - vec_1.x * vec_0.y;
}