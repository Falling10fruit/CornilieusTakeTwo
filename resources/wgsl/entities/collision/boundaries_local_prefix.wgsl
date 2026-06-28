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

var<workgroup> local_array : array<u32, 64>; // u16
var<private> private_array : array<u32, 16>; // u16
var<private> accumulated_sum : u32 = 0;

@compute @workgroup_size(128) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i : u32 = 0; i < 32; i++) {
        let private_index = i >> 1;
        let bit_shift = (i & 1u) * 16;

        let mask = 0xFFFF0000u >> bit_shift;
        private_array[private_index] &= mask;

        let global_index = global_invocation_id.x + i;
        accumulated_sum += entities_buffer_1[global_index].x;
        private_array[private_index] += accumulated_sum << bit_shift;
    }

    local_array[local_id] = accumulated_sum;
    workgroupBarrier();

    for (var stride : u32 = 1; stride < 128; stride <<= 1) {
        var temp : u32;
        if (local_id > stride) { temp = access_local_at(local_id - 1); }
        workgroupBarrier();

        if (local_id > stride) {
            let index = local_id >> 1;
            let bit_shift = (local_id & 1u) * 16;
            let mask = 0xFFFF0000u >> bit_shift;
            
            local_array[index] &= mask;
            local_array[index] += temp << (bit_shift);
        } workgroupBarrier();
    } workgroupBarrier();

    var temp : u32;
    if (local_id < 64) {
        temp = local_array[local_id] & 0xFFFFu;
        local_array[local_id] >>= 16;

        if (local_id != 31) { local_array[local_id + 1] += temp << 16; }
    }

    
}

fn access_local_at(index : u32) -> u32 {   
    let access_index = index >> 1;
    let bit_shift = (index & 1u) * 16;
    return (local_array[access_index] >> (bit_shift)) & 0xFFFFu;
}