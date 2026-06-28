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

var<workgroup> local_array : array<u32, 2048>;

@compute @workgroup_size(256) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i : u32 = 0; i < 8; i++) {
        let index = local_id + i * 256;
        local_array[index] = entities_buffer_1[index].w;
    } workgroupBarrier();

    for (var stride : u32 = 1; stride < 2048; stride <<= 1) {
        var temp : u32;
        for (var i : u32 = 0; i < 8; i++) {
            let index = local_id + i * 256;
            if (index > stride) { temp = local_array[index - stride]; }
        } workgroupBarrier();

        for (var i : u32 = 0; i < 8; i++) {
            let index = local_id + i * 256;
            if (index > stride) { temp = local_array[index - stride];}
        } workgroupBarrier();

    } workgroupBarrier();

    for (var i : u32 = 0; i < 8; i++) {
        let index = local_id + i * 256;

        if (index != 0) {
            entities_buffer_1[(index - 1) * 8912 + 1].w = local_array[index - 1];
        }
    }
}