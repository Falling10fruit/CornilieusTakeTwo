@group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_1 : array<vec4u>;

struct EntityData {
    node_count: u32,
    node_pointer: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(1) @binding(0) var<storage, read> entity_type_data : array<EntityData>;
@group(1) @binding(1) var<storage, read> entity_nodes : array<vec2f>;

@group(2) @binding(0) var<storage, read> cosin_lut : array<vec2f>;
@group(2) @binding(1) var<storage, read_write> hilbert_curve : array<u32>;

override WORLD_HEIGHT : u32; // in terms of chunks
override WORLD_WIDTH : u32; 
override CHUNK_WIDTH : u32;
override LOCAL_POSITION_PRECISION : u32; // i think it was 4096 subdivisions of 1 pixel, idk :)
var<workgroup> entity_redix : array<u32, 32>;

const bounding_corner_signs : array<vec2u, 4> = array(
    vec2u(0u, 0u),
    vec2u(0u, 0x80000000u),
    vec2u(0x80000000u, 0x80000000u),
    vec2u(0x80000000u, 0u),
);

@compute @workgroup_size(256) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    let entity_vector = entities_buffer_0[global_invocation_id.x];

    let entity_type = entity_vector.x >> 23;
    let entity_type_data = entity_type_data[entity_type];

    let entity_dimensions_half = entity_type_data.dimensions * 0.5;
    let entity_rotation_raw = entity_vector.y & 0x1FFFu;
    let rotation_cos = cosin_lut[entity_rotation_raw].x;
    let rotation_sin = cosin_lut[entity_rotation_raw].y;
    var max_width = 0.0; var max_height = 0.0;
    for (var i = 0; i < 4; i++) {
        let edge_x = bitcast<f32>((bitcast<u32>(entity_dimensions_half.x) & 0x7FFFFFFFu) | bounding_corner_signs[i].x);
        let edge_y = bitcast<f32>((bitcast<u32>(entity_dimensions_half.y) & 0x7FFFFFFFu) | bounding_corner_signs[i].y);
        let rotated_edge = vec2f(edge_x * rotation_cos - edge_y * rotation_sin, edge_x * rotation_sin + edge_y * rotation_cos);
        max_width = max(max_width, abs(rotated_edge.x));
        max_height = max(max_height, abs(rotated_edge.y));
    }
    let broad_dimensions = vec2u(bitcast<u32>(max_width), bitcast<u32>(max_height));
    
    let entity_chunk_index = (entity_vector.x >> 7) & 0xFFu;
    let entity_chunk_position = vec2u(entity_chunk_index % WORLD_WIDTH, entity_chunk_index / WORLD_WIDTH);
    let entity_local_position = vec2u(((entity_vector.x & 0x7Fu) << 6) + (entity_vector.y >> 26), (entity_vector.y >> 13) & 0x1FFFu);
    
    entities_buffer_1[global_invocation_id.x] = vec4u((entity_chunk_position << vec2u(13, 13)) + entity_local_position, broad_dimensions);
}

// 0000000 00000001 00000010 00000011 0000100 101 110 111 1000 1001 1010 1011 1100 1101 1110 1111 10000 10001 10010 10011 10100 10101 10110 10111 11000
//    0         1       2       3       4
//  0.0000   0.0001 0.0002    0.0003
// 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14
// 0 1 2 3 4 5 6 7 10 11 12 13 14 15 16 17 20 base 8

// sign    exponent     mantissa
// 0       10101010    10101010101010101010101
//      2^(exponent - 128) * mantissa / 2^23

//            
// 0 10000000 10000000000000000000000 = 0.5
// 2^(128 - 128) * 