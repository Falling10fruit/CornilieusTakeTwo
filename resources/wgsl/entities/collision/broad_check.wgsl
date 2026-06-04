@group(0) @binding(0) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_1 : array<vec4u>;

struct EntityData {
    node_count: u32,
    node_pointer: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(1) @binding(0) var<storage, read> entity_type_data : array<EntityData>;

@group(2) @binding(0) var<storage, read> cosin_lut : array<vec2f>;
@group(2) @binding(1) var<storage, read_write> hilbert_curve : array<u32>;

override WORLD_WIDTH_IN_CHUNKS : u32; 
override WORLD_HEIGHT_IN_CHUNKS : u32;

const chunk_offsets : array<vec2u, 4> = array(
    vec2u(1, 1),
    vec2u(1, 0),
    vec2u(0, 1),
    vec2u(0, 0),
);

var<private> colliding_entity_distances_squared : vec4f;
var<private> colliding_entity_indexes : vec4u;
var<private> insert_entity_index_pointer : u32;

@compute @workgroup_size(32) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    colliding_entity_distances_squared.x = bitcast<f32>(0x7FFFFFFFu);
    colliding_entity_distances_squared.y = bitcast<f32>(0x7FFFFFFEu);
    colliding_entity_distances_squared.z = bitcast<f32>(0x7FFFFFFDu);
    colliding_entity_distances_squared.w = bitcast<f32>(0x7FFFFFFCu);
    colliding_entity_indexes.x = (0 << 30) + global_invocation_id.x;
    colliding_entity_indexes.y = (1 << 30) + global_invocation_id.x;
    colliding_entity_indexes.z = (2 << 30) + global_invocation_id.x;
    colliding_entity_indexes.w = (3 << 30) + global_invocation_id.x;
    let entity_broad_vector = entities_buffer_1[global_invocation_id.x];

    let this_center = vec2f(entity_broad_vector.xy) / 4096.0;
    let this_extent = bitcast<vec2f>(entity_broad_vector.zy);

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
                let other_extent = bitcast<vec2f>(other_entity_broad_vector.yz);
                let other_center = vec2f(other_entity_broad_vector.xy) / 4096.0;
                let delta_center = other_center - this_center;
                let distance_cmp = delta_center <= (other_extent + this_extent);
                let delta_squared = delta_center * delta_center;
                let dist_squared = delta_squared.x + delta_squared.y;

                if (distance_cmp.x && distance_cmp.y && dist_squared < colliding_entity_distances_squared.x) {
                    colliding_entity_distances_squared.x = dist_squared;
                    
                    let temp_0 = colliding_entity_distances_squared.x;
                    let temp_1 = colliding_entity_distances_squared.y;
                    colliding_entity_distances_squared.x = max(temp_0, temp_1);
                    colliding_entity_distances_squared.y = min(temp_0, temp_1);

                    let temp_2 = colliding_entity_distances_squared.y;
                    let temp_3 = colliding_entity_distances_squared.z;
                    colliding_entity_distances_squared.y = max(temp_2, temp_3);
                    colliding_entity_distances_squared.z = min(temp_2, temp_3);
                    
                    let temp_4 = colliding_entity_distances_squared.z;
                    let temp_5 = colliding_entity_distances_squared.w;
                    colliding_entity_distances_squared.z = max(temp_4, temp_5);
                    colliding_entity_distances_squared.w = min(temp_4, temp_5);

                    //     index at dist squared    index at colliding entities
                    //          0101                    0101
                    // From the least significant bit on the right
                    let entity_0_dist_squared_index = colliding_entity_indexes.x >> 30;
                    let dist_squared_of_entity_0 = colliding_entity_distances_squared[entity_0_dist_squared_index];
                    insert_entity_index_pointer = select(insert_entity_index_pointer, (entity_0_dist_squared_index << 4) + 0, dist_squared < dist_squared_of_entity_0);

                    let entity_1_dist_squared_index = colliding_entity_indexes.y >> 30;
                    let dist_squared_of_entity_1 = colliding_entity_distances_squared[entity_1_dist_squared_index];
                    insert_entity_index_pointer = select(insert_entity_index_pointer, (entity_1_dist_squared_index << 4) + 1, dist_squared < dist_squared_of_entity_1);
                    
                    let entity_2_dist_squared_index = colliding_entity_indexes.z >> 30;
                    let dist_squared_of_entity_2 = colliding_entity_distances_squared[entity_2_dist_squared_index];
                    insert_entity_index_pointer = select(insert_entity_index_pointer, (entity_2_dist_squared_index << 4) + 2, dist_squared < dist_squared_of_entity_2);
                    
                    let entity_3_dist_squared_index = colliding_entity_indexes.w >> 30;
                    let dist_squared_of_entity_3 = colliding_entity_distances_squared[entity_3_dist_squared_index];
                    insert_entity_index_pointer = select(insert_entity_index_pointer, (entity_3_dist_squared_index << 4) + 3, dist_squared < dist_squared_of_entity_3);

                    colliding_entity_indexes[insert_entity_index_pointer & 3u] = (((insert_entity_index_pointer >> 4) & 3u) << 30) + other_entity_index;
                }
            }
        }
    }

    workgroupBarrier();

    entities_buffer_1[global_invocation_id.x] = colliding_entity_indexes & vec4u(0x3FFFFFFFu, 0x3FFFFFFFu, 0x3FFFFFFFu, 0x3FFFFFFFu);
}