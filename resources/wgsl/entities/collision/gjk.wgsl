struct EntityData {
    gjk_bounds_dictionary_pointer: u32,
    gjk_bounds_count: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(0) @binding(0) var<storage, read> entity_type_data_buffer : array<EntityData>;
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

override HALF_PHASE : u32 = 0;

// x
// boundary id  (the rest of the 24 bits) former entity id
//   01010101           0001100100101010...
// y
// boundary id  (the rest of the 24 bits) latter entity id
//   01010101           0000010010101010...
// z
// boundary id 1 boundary id 2 boundary id 3    :) each with 8 bits ig eheh
//    01010101     01010101    01010101            01010101
// w
// boundary id 1 boundary id 2 boundary id 3    wow so cool
//    01010101     01010101    01010101            01010101

var<private> collider_boundary_counts : vec4u;

fn cross2d(a: vec2f, b: vec2f) -> f32 { return a.x * b.y - a.y * b.x; }
fn cross2d_vec_scalar(a: vec2f, b: f32) -> vec2f { return vec2f(b * a.y, -b * a.x); }

// 512 * 512 = 262,144 total workgroups please (for a total of 2^23 threads)
// the y direction will be used to scale the algorithm
@compute @workgroup_size(32) fn setup_collision_pairs(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32,
) {
    let global_index = global_invocation_id.x + global_invocation_id.y * 512 * 32;
    let index_offset = arrayLength(&entities_buffer_meta) / 2;
    var memory_offset = select(entities_buffer_meta[index_offset + global_index - 1].y, 0, local_id == 0);

    let collider_data_vector = entities_buffer_meta[global_index];
    let former_boundary_count = collider_data_vector.x >> 28;
    collider_boundary_counts = (collider_data_vector >> vec4u(24, 24, 24, 24)) & vec4u(0xFu, 0xFu, 0xFu, 0xFu);
    
    let collider_type_id =
        (collider_data_vector.y >> 28) +
        ((collider_data_vector.z >> 28) << 4) +
        ((collider_data_vector.w >> 28) << 8);

    let former_collider_index = HALF_PHASE * index_offset + global_index;
    for (var former_boundary_index : u32 = 0; former_boundary_index < former_boundary_count; former_boundary_index++) {
        for (var i : u32; i < 4; i++) {
            let latter_boundary_count = collider_boundary_counts[i];
            let latter_collider_index = collider_data_vector[i] & 0xFFFFFFu;

            for (var latter_boundary_index : u32 = 0; latter_boundary_index < latter_boundary_count; latter_boundary_index++) {
                let memory_index = memory_offset + former_boundary_index;

                entities_buffer_1[memory_index].x = (former_boundary_index << 24) + former_collider_index;
                entities_buffer_1[memory_index].y = (latter_boundary_index << 24) + latter_collider_index;
                entities_buffer_1[memory_index].z = collider_type_id;
            }

            memory_offset += latter_boundary_count;
        }
    }
}

struct PeakNode {
    id: u32,
    node: vec2f,
    product: f32,
}

// 64 * 512 (for a total of 2^24 threads)
// the y direction will be used to scale the algorithm
@compute @workgroup_size(128) fn setup_collision_nodes(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let index_offset = arrayLength(&entities_buffer_meta);
    let global_index = global_invocation_id.x + global_invocation_id.y * 128 * 64;
    let collision_vector = entities_buffer_1[global_index];

    let former_collider_id = collision_vector.x & 0xFFFFFFu;
    let former_boundary_id = collision_vector.x >> 24;
    let former_type_id = collision_vector.z & 0x3FFu;

    let latter_collider_id = collision_vector.y & 0xFFFFFFu;
    let latter_boundary_id = collision_vector.y >> 24;
    let latter_type_id = entities_buffer_meta[index_offset + latter_collider_id].x;

    let center_delta_packed =
        bitcast<vec2i>(entities_buffer_meta[index_offset + latter_collider_id].zw) - 
        bitcast<vec2i>(entities_buffer_meta[index_offset + former_collider_id].zw);
    let direction_0 = vec2f(-center_delta_packed) / 64.0;
        
    let former_node_0: PeakNode = support_function(former_type_id, former_collider_id,  direction_0);
    let latter_node_0: PeakNode = support_function(latter_type_id, latter_collider_id, -direction_0);
    let support_node_0 = latter_node_0.node - former_node_0.node;

    let direction_1 = -support_node_0;

    let former_node_1: PeakNode = support_function(former_type_id, former_collider_id,  direction_1);
    let latter_node_1: PeakNode = support_function(former_type_id, former_collider_id, -direction_1);
    let support_node_1 = latter_node_1.node - latter_node_0.node;

    let support_delta = support_node_1 - support_node_0;
    let direction_2 = cross2d_vec_scalar(support_delta, cross2d(-support_node_0, support_delta));

    let former_node_2: PeakNode = support_function(former_type_id, former_collider_id,  direction_2);
    let latter_node_2: PeakNode = support_function(former_type_id, former_collider_id, -direction_2);
    let support_node_2 = latter_node_2.node - former_node_2.node;

    
}

// gjk_bounds_dictionary_pointer
//    \/                                 ----------------------   ------------------------
//  (0, 3), (3, 4), (7, 5), (12, 4), (2, 3), (4, 6), (-3, -5), (3, 1), (-4, 5), (-2, -1)
//  \-----------------------------/
//          gjk_bounds_count

fn support_function(type_id : u32, boundary_id : u32, direction_vector : vec2f) -> PeakNode {
    let entity_type_data = entity_type_data_buffer[type_id];
    let boundary_data = bitcast<vec2u>(entity_nodes[entity_type_data.gjk_bounds_dictionary_pointer + boundary_id]);
    let boundary_nodes_index = entity_type_data.gjk_bounds_dictionary_pointer + entity_type_data.gjk_bounds_count + boundary_data.x;

    let first_node = entity_nodes[boundary_nodes_index];
    var candidate : PeakNode = PeakNode(0, first_node, dot(first_node, direction_vector));
    for (var i : u32 = 0; i < boundary_data.y; i++) {
        let index = boundary_nodes_index + i;
        let node = entity_nodes[index];
        let product = dot(node, direction_vector);

        if (product > candidate.product) { candidate = PeakNode(i, node, product); }
    }

    return candidate;
}

