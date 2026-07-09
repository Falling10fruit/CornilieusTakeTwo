struct EntityData {
    gjk_bounds_dictionary_pointer: u32,
    gjk_bounds_count: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(0) @binding(0) var<storage, read>       entity_type_data_buffer : array<EntityData>;
@group(0) @binding(1) var<storage, read>       entity_nodes : array<vec2f>;
@group(0) @binding(1) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<vec4u>;
@group(0) @binding(6) var<storage, read_write> entities_buffer_meta : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> debug_buffer : f32; // ##DEBUG_TYPE##=
@group(1) @binding(1) var<storage, read>       cosin_lut : array<vec2f>;
@group(1) @binding(2) var<storage, read>       hilbert_curve : array<u32>;
@group(1) @binding(3) var<storage, read>       world_data : array<u32>;

override WORLD_WIDTH_IN_CHUNKS : u32; 
override WORLD_HEIGHT_IN_CHUNKS : u32;

const chunk_offsets : array<vec2u, 4> = array(
    vec2u(1, 1),
    vec2u(1, 0),
    vec2u(0, 1),
    vec2u(0, 0),
);

var<private> colliding_entity_distances_squared : array<f32, 4>;
var<private> colliding_entity_indicies : array<u32, 4>;
var<private> insert_entity_index_pointer : u32;

@compute @workgroup_size(32) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    colliding_entity_distances_squared[0] = bitcast<f32>(0x7FFFFFF8u);
    colliding_entity_distances_squared[1] = bitcast<f32>(0x7FFFFFF9u);
    colliding_entity_distances_squared[2] = bitcast<f32>(0x7FFFFFFAu);
    colliding_entity_distances_squared[3] = bitcast<f32>(0x7FFFFFFBu);
    colliding_entity_indicies[0] = global_invocation_id.x;
    colliding_entity_indicies[1] = global_invocation_id.x;
    colliding_entity_indicies[2] = global_invocation_id.x;
    colliding_entity_indicies[3] = global_invocation_id.x;
    let entity_broad_vector = entities_buffer_1[global_invocation_id.x];

    let this_gjk_boundaries_count = (entity_broad_vector.z & 3u) + ((entity_broad_vector.w & 3u) << 2);
    let this_entity_type_id = ((entity_broad_vector.z >> 2) & 0x1Fu) + ((entity_broad_vector.w << 3) & 0x3E0u);
    let this_extent = bitcast<vec2f>(entity_broad_vector.zw & vec2u(0xFFFFE000u, 0xFFFFE000u));

    let entity_chunk_position = entity_broad_vector.xy >> vec2u(13, 13);
    let local_position_bias = ((entity_broad_vector.xy & vec2u(0x1000u, 0x1000u)) >> vec2u(12, 12));
    let chunk_edge_check = vec2u(entity_chunk_position == vec2u(WORLD_WIDTH_IN_CHUNKS - 1, WORLD_HEIGHT_IN_CHUNKS - 1));
    let chunk_bias = local_position_bias * chunk_edge_check;
    let chunk_base = entity_chunk_position + chunk_bias;

    for (var i = 0; i < 4; i++) {
        let chunk_offset = chunk_offsets[i];
        let chunk_position = chunk_base - chunk_offset;
        let chunk_index = chunk_position.x + chunk_position.y * WORLD_WIDTH_IN_CHUNKS;
        let current_chunk_first_entity_index = chunk_indicies[chunk_index];
        var next_chunk_first_entity_index = chunk_indicies[chunk_index + 1];
        
        if (chunk_offset.x > chunk_base.x || chunk_offset.y > chunk_base.y) { next_chunk_first_entity_index = current_chunk_first_entity_index; }

        for (var other_entity_index = current_chunk_first_entity_index; other_entity_index < next_chunk_first_entity_index; other_entity_index++) {
            if (other_entity_index != global_invocation_id.x) {
                let other_entity_broad_vector = entities_buffer_1[other_entity_index];
                
                let other_gjk_boundaries_count = (other_entity_broad_vector.z & 3u) + ((other_entity_broad_vector.w & 3u) << 2);
                let other_extent = bitcast<vec2f>(other_entity_broad_vector.zw & vec2u(0xFFFFFF80u, 0xFFFFFF80u));

                let delta_center_u32 = other_entity_broad_vector.xy - entity_broad_vector.xy;
                let delta_center = bitcast<vec2f>(delta_center_u32) / 4096.0;

                let distance_cmp = delta_center <= (other_extent + this_extent);
                let delta_squared = delta_center * delta_center;
                let this_distance_squared = delta_squared.x + delta_squared.y;

                if (distance_cmp.x && distance_cmp.y && this_distance_squared < colliding_entity_distances_squared[3]) {
                    var insert_entity_at_index: u32 = 3;
                    for (var i : u32 = 0; i < 3; i++) {
                        let index = (colliding_entity_indicies[i] >> 28) & 0x7u;
                        let distance_squared = colliding_entity_distances_squared[index];
                        insert_entity_at_index = select(insert_entity_at_index, i, this_distance_squared < distance_squared);
                    }

                    colliding_entity_indicies[insert_entity_at_index] =
                        (insert_entity_at_index << 28) +
                        (other_gjk_boundaries_count << 24) +
                        other_entity_index;
                    colliding_entity_distances_squared[3] = this_distance_squared;
                    
                    for (var i = 0; i < 3; i++) {
                        let temp_0 = colliding_entity_distances_squared[i];
                        let temp_1 = colliding_entity_distances_squared[i + 1];
                        colliding_entity_distances_squared[i] = min(temp_0, temp_1);
                        colliding_entity_distances_squared[i + 1] = max(temp_0, temp_1);
                    }
                }
            }
        }
    }

    entities_buffer_meta[global_invocation_id.x] = (vec4u(
        colliding_entity_indicies[0],
        colliding_entity_indicies[1],
        colliding_entity_indicies[2],
        colliding_entity_indicies[3],
    ) & vec4u(0xFFFFFFFu, 0xFFFFFFFu, 0xFFFFFFFu, 0xFFFFFFFu)) + vec4u(
        this_gjk_boundaries_count << 28,
        (this_entity_type_id & 0xFu) << 28,
        ((this_entity_type_id >> 4) & 0xFu) << 28,
        (this_entity_type_id >> 8) << 28
    );

    let this_entity_rotation = ((entity_broad_vector.z >> 7) & 0x3Fu) + (((entity_broad_vector.w >> 7) & 0x3Fu) << 6);
    entities_buffer_meta[arrayLength(&entities_buffer_meta)/2 + global_invocation_id.x].x = this_entity_rotation << 10;
}