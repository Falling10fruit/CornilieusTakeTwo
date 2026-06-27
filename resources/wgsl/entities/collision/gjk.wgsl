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

override world_width_in_chunks : u32; 
override world_height_in_chunks : u32;

override entity_type_count : u32 = 5;
var<workgroup> entity_type_data_lds : array<EntityData, entity_type_count>;
override entity_nodes_count : u32 = 31; //idk I just added the total number of nodes I counted, pls replace with a proper number?
var<workgroup> entity_nodes_lds : array<vec2f, entity_nodes_count>;

@compute @workgroup_size(256) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    if (local_id < entity_type_count) { entity_type_data_lds[local_id] = entity_type_data[local_id]; }
    if (local_id < entity_nodes_count) { entity_nodes_lds[local_id] = entity_nodes[local_id]; }
    workgroupBarrier();

    let this_entity_vector = entities_buffer_0[global_invocation_id.x];
    let this_entity_type = this_entity_vector.x >> 23;
    let this_entity_type_data = entity_type_data_lds[this_entity_type];
    let this_entity_chunk_index = (this_entity_vector.x >> 7) & 0xFFu;
    let this_entity_chunk_position = vec2u(this_entity_chunk_index % world_width_in_chunks, this_entity_chunk_index / world_width_in_chunks);
    let this_entity_local_position = vec2u(((this_entity_vector.x & 0x7Fu) << 6) + (this_entity_vector.y >> 26), (this_entity_vector.y >> 13) & 0x1FFFu);
    let this_entity_global_position = (this_entity_chunk_position << vec2u(13, 13)) + this_entity_local_position;
    let this_entity_cosin = cosin_lut[this_entity_vector.y & 0x1FFFu];
    let this_entity_velocity = vec2f(parse_velocity(this_entity_vector.z >> 22), parse_velocity((this_entity_vector.z >> 12) & 0x3FFu));

    let colliding_entities_vector = entities_buffer_meta[global_invocation_id.x];

    let entity_0_vector = entities_buffer_0[colliding_entities_vector.x];
    let entity_0_type = entity_0_vector.x >> 23;
    let entity_0_type_data = entity_type_data_lds[entity_0_type];
    let entity_0_chunk_index = (entity_0_vector.x >> 7) & 0xFFu;
    let entity_0_chunk_position = vec2u(entity_0_chunk_index % world_width_in_chunks, entity_0_chunk_index / world_width_in_chunks);
    let entity_0_local_position = vec2u(((entity_0_vector.x & 0x7Fu) << 6) + (entity_0_vector.y >> 26), (entity_0_vector.y >> 13) & 0x1FFFu);
    let entity_0_global_position = (entity_0_chunk_position << vec2u(13, 13)) + entity_0_local_position;
    let entity_0_cosin = cosin_lut[entity_0_vector.y & 0x1FFFu];
    let entity_0_velocity = vec2f(parse_velocity(entity_0_vector.z >> 22), parse_velocity((entity_0_vector.z >> 12) & 0x3FFu));
    
    let entity_1_vector = entities_buffer_0[colliding_entities_vector.y];
    let entity_1_type = entity_1_vector.x >> 23;
    let entity_1_type_data = entity_type_data_lds[entity_1_type];
    let entity_1_chunk_index = (entity_1_vector.x >> 7) & 0xFFu;
    let entity_1_chunk_position = vec2u(entity_1_chunk_index % world_width_in_chunks, entity_1_chunk_index / world_width_in_chunks);
    let entity_1_local_position = vec2u(((entity_1_vector.x & 0x7Fu) << 6) + (entity_1_vector.y >> 26), (entity_1_vector.y >> 13) & 0x1FFFu);
    let entity_1_global_position = (entity_1_chunk_position << vec2u(13, 13)) + entity_1_local_position;
    let entity_1_cosin = cosin_lut[entity_1_vector.y & 0x1FFFu];

    let entity_2_vector = entities_buffer_0[colliding_entities_vector.z];
    let entity_2_type = entity_2_vector.x >> 23;
    let entity_2_type_data = entity_type_data_lds[entity_2_type];
    let entity_2_chunk_index = (entity_2_vector.x >> 7) & 0xFFu;
    let entity_2_chunk_position = vec2u(entity_2_chunk_index % world_width_in_chunks, entity_2_chunk_index / world_width_in_chunks);
    let entity_2_local_position = vec2u(((entity_2_vector.x & 0x7Fu) << 6) + (entity_2_vector.y >> 26), (entity_2_vector.y >> 13) & 0x1FFFu);
    let entity_2_global_position = (entity_2_chunk_position << vec2u(13, 13)) + entity_2_local_position;
    let entity_2_cosin = cosin_lut[entity_2_vector.y & 0x1FFFu];
    
    let entity_3_vector = entities_buffer_0[colliding_entities_vector.w];
    let entity_3_type = entity_3_vector.x >> 23;
    let entity_3_type_data = entity_type_data_lds[entity_3_type];
    let entity_3_chunk_index = (entity_2_vector.x >> 7) & 0xFFu;
    let entity_3_chunk_position = vec2u(entity_3_chunk_index % world_width_in_chunks, entity_3_chunk_index / world_width_in_chunks);
    let entity_3_local_position = vec2u(((entity_3_vector.x & 0x7Fu) << 6) + (entity_3_vector.y >> 26), (entity_3_vector.y >> 13) & 0x1FFFu);
    let entity_3_global_position = (entity_3_chunk_position << vec2u(13, 13)) + entity_3_local_position;
    let entity_3_cosin = cosin_lut[entity_3_vector.y & 0x1FFFu];
    
    for (var this_node_offset : u32 = 0; this_node_offset < this_entity_type_data.node_count; this_node_offset++) {
        let this_node_index = this_entity_type_data.node_pointer + this_node_offset;
        let this_node = rotate_node(entity_nodes_lds[this_node_index], this_entity_cosin);
        let this_next_node = rotate_node(entity_nodes_lds[this_node_index + 1], this_entity_cosin);
        let this_node_delta = this_next_node - this_node;
        let this_node_coordinates = this_node + vec2f(this_entity_global_position) / 4096.0;

        for (var other_node_offset : u32 = 0; other_node_offset < entity_0_type_data.node_count; other_node_offset++) {
            let other_node_index = entity_0_type_data.node_pointer + other_node_offset;
            let other_node = rotate_node(entity_nodes_lds[other_node_index], entity_0_cosin);
            let other_next_node = rotate_node(entity_nodes_lds[other_node_index + 1], entity_0_cosin);
            let other_node_delta = other_next_node - other_node;
            let other_node_coordinates = other_node + vec2f(entity_0_global_position) / 4096.0;

            let lambda = cross_2d(other_node_coordinates - this_node_coordinates, other_node_delta) / cross_2d(this_node_delta, other_node_delta);
            let intersection_success = 0.0 >= lambda && lambda <= 1.0;
        }
    }
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

fn parse_velocity (bits : u32) -> f32 {
    let sign_bit = bits >> 9;
    let exponent = (bits >> 4) & 0x1Fu;
    let mantissa = bits & 0xFu;
    
    return bitcast<f32>((sign_bit << 31) + ((exponent + 120) << 23) + (mantissa << 19));
}