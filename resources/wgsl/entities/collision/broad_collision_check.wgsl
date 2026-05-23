@group(0) @binding(0) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_1 : array<vec4u>;

override world_width_in_chunks : u32; 
override world_height_in_chunks : u32;
var<workgroup> entity_redix : array<u32, 32>;

@group(2) @binding(0) var<storage, read> cosin_lut : array<vec2f>;

const chunk_offsets : array<vec2u, 4> = array(
    vec2u(1, 1),
    vec2u(1, 0),
    vec2u(0, 1),
    vec2u(0, 0),
);

@compute @workgroup_size(32) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    let entity_broad_vector = entities_buffer_1[global_invocation_id.x];
    let entity_chunk_position = entity_broad_vector.xy >> vec2u(13, 13);
    let local_position_bias = ((entity_broad_vector.xy & vec2u(0x1000u, 0x1000u)) >> vec2u(12, 12));
    let chunk_edge_check = vec2u(entity_chunk_position == vec2u(world_width_in_chunks - 1, world_height_in_chunks - 1));
    let chunk_bias = local_position_bias * chunk_edge_check;
    let chunk_base = entity_chunk_position + chunk_bias;

    for (var i = 0; i < 4; i++) {
        let chunk_offset = chunk_offsets[i];
        let chunk_position = chunk_base - chunk_offset;
        let chunk_index = chunk_position.x + chunk_position.y * world_width_in_chunks;
        let current_chunk_first_entity_index = chunk_indicies[chunk_index];
        var next_chunk_first_entity_index = chunk_indicies[chunk_index + 1];
        
        if (chunk_offset.x > chunk_base.x || chunk_offset.y > chunk_base.y) { next_chunk_first_entity_index = current_chunk_first_entity_index; }

        for (var other_entity_index = current_chunk_first_entity_index; other_entity_index < next_chunk_first_entity_index; other_entity_index++) {
            other_entity
        }
    }
}