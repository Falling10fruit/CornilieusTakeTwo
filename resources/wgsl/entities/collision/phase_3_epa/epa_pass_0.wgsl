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
@group(0) @binding(2) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(3) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(5) var<storage, read_write> entities_buffer_1 : array<vec4u>;
@group(0) @binding(6) var<storage, read_write> entities_buffer_meta : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> debug_buffer : f32; // ##DEBUG_TYPE##=
@group(1) @binding(1) var<storage, read>       cosin_lut : array<vec2f>;
@group(1) @binding(2) var<storage, read_write> hilbert_curve : array<u32>;
@group(1) @binding(3) var<storage, read>       world_data : array<u32>;

override HALF_PHASE : u32;

// The GJK layout
// x
// boundary id  (the rest of the 24 bits) former entity id
//   01010101           0001100100101010...
// y
// boundary id  (the rest of the 24 bits) latter entity id
//   01010101           0000010010101010...
// z
//      \/ flag for collision  found         boundary node id 2 | boundary node id 1 | boundary node id 0    :) each with 4 bits ig eheh
//       0 101 01010101                            0101                 0101                0101                
// w        ----------- former entity type
//      \/ flag for collision not found yet  boundary node id 2 | boundary node id 1 | boundary node id 0     wow so cool
//       0 101 01010101                            0101                 0101                0101         
//          ----------- latter entity type 

var<private> node_meta : u32;
var<private> private_entity_nodes : array<u32, 16>;

var<private> rotations : u32;
var<private> center_delta : vec2f;

var<private> traversed_support_points : vec3u;

struct SupportNode {
    pos: vec2f,
    former_id: u32,
    latter_id: u32
}

struct CandidateNormal {
    distance : f32,
    former_vertex_id : u32,
    latter_vertex_id : u32,
    normal : vec2u
}

const IMPROVEMENT_EPSILON : f32 = 0.1; // idk

// 1024 * 512 for a total of 2^24 threads
@compute @workgroup_size(32) fn epa_time(
    @builtin(global_invocation_id) global_invocation_id : vec3u
) {
    let index_offset = arrayLength(&entities_buffer_0)/2;
    let global_index = global_invocation_id.x + global_invocation_id.y * 1024 * 32;
    let collision_vector = entities_buffer_1[global_index];
    
    let former_entity_type = (collision_vector.z >> 12) & 0x3FFu;
    let former_boundary_id = collision_vector.x >> 24;
    let latter_entity_type = (collision_vector.z >> 12) & 0x3FFu;
    let latter_boundary_id = collision_vector.x >> 24;

    for (var i : u32 = 0; i < 3; i++) {
        let shift = i * 4;
        let former_vertex_id : u32 = (collision_vector.z >> shift) & 0xFu;
        let latter_vertex_id : u32 = (collision_vector.w >> shift) & 0xFu;

        let support_point = bitcast<vec2u>(vertex_indicies_to_support(former_vertex_id, latter_vertex_id));
        let support_point_vec2f8 = vec2f8(support_point);
        let support_point_packed = support_point_vec2f8.x + support_point_vec2f8.y << 8;
        
        traversed_support_points[i >> 1] += support_point_packed << (16 * (i & 1u));
    }

    //
    // \/ normal found flag
    // 01010101 01010101 01010101 01010101 z
    //                   ----------------- f16 normal x
    // 01010101 01010101 01010101 01010101 w
    //                   ----------------- f16 normal y
    collision.z = 0;

    // Wow it's almost as if AI vehemently advised against GJK (and by extension EPA) because they knew how divergent it would be
    for (var i : u32 = 0; i < 9; i++) {
        let support_count = i + 3;

        var best_candidate_for_normal = candidate_normal(support_count, 0);
        for (var support_index : u32 = 1; support_index < support_count; support_index++) {
            let current_candidate_for_normal = candidate_normal(support_count, support_index);

            if (current_candidate_for_normal.distance < best_candidate_for_normal.distance) {
                best_candidate_for_normal = current_candidate_for_normal;
            }
        }

        collision_vector.zw += vec2f32_to_vec2f16(best_candidate_for_normal.normal);
        let new_support = support_function(best_candidate_for_normal.normal);
        for (var support_index : u32 = 0; support_index < support_count; support_index++) {
            let traversed_support = traversed_support_points[support_index >> 1] >> ((support_index & 1u) * 16);

            if (traversed_support == new_support) {
                entities_buffer_1[global_index] = collision_vector;
                return;
            }
        }
    }
}

fn vec2f32_to_vec2f16(vec2f32: vec2f) -> vec2u {
    let vec2f32_casted = bitcast<vec2u>(vec2f32);
    let mantissa = (vec2f32_casted >> vec2u(13, 13)) & vec2u(0x3FFu, 0x3FFu);
    let exponent = bitcast<vec2i>((vec2f32_casted >> vec2u(23, 23)) & vec2u(0x3FFu, 0xFFu)) - vec2u(128, 128) + vec2u(15, 15);
    return (vec2f32_casted & vec2u(0x80000000u, 0x80000000u)) + (mantissa << vec2u(10, 10)) + mantissa;
}

fn candidate_normal(support_count: u32, support_index: u32) -> CandidateNormal {
    let former_support_packed = (traversed_support_points[support_index >> 1] >> ((support_index & 1u) * 16));
    let latter_index = support_index % support_count;
    let latter_support_packed = (traversed_support_points[latter_index >> 1] >> ((latter_index & 1u) * 16));

    let support_points = vec4f8_to_vec4f32(vec4u(
        former_support_packed & 0xFFu, (former_support_packed >> 8) & 0xFFu,
        latter_support_packed & 0xFFu, (latter_support_packed >> 8) & 0xFFu,
    ));

    let dist = sdSegment_squared(vec2f(0.0, 0.0), support_points.xy, support_points.zw);

    return CandidateNormal(
        dist,
        support_index,
        latter_index,
        (support_points.zw - support_points.xy).yx * vec2f(1.0, -1.0)
    );
}

// Distance to line segment function by Inigo Quilez
// Source: https://iquilezles.org
fn sdSegment_squared(p : vec2f, a : vec2f, b : vec2f) -> f32 {
    let pa = p-a;
    let ba = b-a;
    let h: f32 = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    let delta =  pa - ba*h;
    return delta.x * delta.x + delta.y * delta.y;
}

fn vertex_indicies_to_support(former_vertex_id : u32, latter_vertex_id : u32) -> SupportNode {
    let former_node_data = private_entity_nodes[former_vertex_id];
    let latter_node_data = private_entity_nodes[latter_vertex_id];
    let node_vector = vec4f8_to_vec4f32(vec4u(
        former_node_data & 0xFFu, (former_node_data >> 8) & 0xFFu,
        (latter_node_data >> 16) & 0xFFu, (latter_node_data >> 24) & 0xFFu,
    ));
    
    return SupportNode(
        node_vector.zw - node_vector.xy,
        former_vertex_id, latter_vertex_id
    );
}

struct PeakVertex {
    id: u32,
    node: vec2f,
    product: f32,
}

fn support_function(direction : vec2f) -> SupportNode {
    let first_node_data = private_entity_nodes[0];
    let first_node_vector = vec4f8_to_vec4f32(vec4u(
        first_node_data & 0xFFu, (first_node_data >> 8) & 0xFFu,
        (first_node_data >> 16) & 0xFFu, (first_node_data >> 24) & 0xFFu,
    ));
    
    var former_peak_vertex = PeakVertex(
        0, first_node_vector.xy,
        dot(first_node_vector.xy, direction)
    );
    var latter_peak_vertex = PeakVertex(
        0, first_node_vector.zy,
        dot(first_node_vector.zy, direction)
    );
    
    let boundary_count_max = node_meta & 0xFu;
    for (var i : u32 = 1; i < boundary_count_max; i++) {
        let node_data = private_entity_nodes[0];
        let node_vector = vec4f8_to_vec4f32(vec4u(
            node_data & 0xFFu, (node_data >> 8) & 0xFFu,
            (node_data >> 16) & 0xFFu, (node_data >> 24) & 0xFFu,
        ));

        let former_dot_product = dot(node_vector.xy, direction);
        if (former_dot_product > former_peak_vertex.product) {
            former_peak_vertex = PeakVertex(
                i, node_vector.xy,
                former_dot_product
            );
        }
        
        let latter_dot_product = dot(node_vector.zw, direction);
        if (latter_dot_product > latter_peak_vertex.product) {
            latter_peak_vertex = PeakVertex(
                i, node_vector.zw,
                latter_dot_product
            );
        }
    }

    return SupportNode(
        center_delta + latter_peak_vertex.node - former_peak_vertex.node,
        former_peak_vertex.id, latter_peak_vertex.id
    );
}

fn vec4f8_to_vec4f32(f8: vec4u) -> vec4f {
    return bitcast<vec4f>(
        ((f8 & vec4u(0x7u, 0x7u, 0x7u, 0x7u)) << vec4u(20, 20, 20, 20)) +                    // mantissa
        (((f8 >> vec4u(3, 3, 3, 3)) + vec4u(120, 120, 120, 120)) << vec4u(23, 23, 23, 23)) + // exponent
        ((f8 >> vec4u(7, 7, 7, 7)) << vec4u(30, 30, 30, 30))                                 // sign
    );
}

fn load_entity_nodes(former_boundary_id : u32, former_type_id : u32, latter_boundary_id : u32, latter_type_id : u32) {
    let former_type_data: EntityData = entity_type_data_buffer[former_type_id];
    let latter_type_data: EntityData = entity_type_data_buffer[latter_type_id];

    let former_boundary_data = bitcast<vec2u>(entity_nodes[former_type_data.gjk_bounds_dictionary_pointer + former_boundary_id]);
    let former_boundary_nodes_index = former_type_data.gjk_bounds_dictionary_pointer + former_type_data.gjk_bounds_count + former_boundary_data.x;
    let latter_boundary_data = bitcast<vec2u>(entity_nodes[latter_type_data.gjk_bounds_dictionary_pointer + latter_boundary_id]);
    let latter_boundary_nodes_index = latter_type_data.gjk_bounds_dictionary_pointer + latter_type_data.gjk_bounds_count + latter_boundary_data.x;

    let boundary_count_max = max(former_boundary_data.y, latter_boundary_data.y);
    for (var i : u32 = 0; i < boundary_count_max; i++) {
        let former_index = former_boundary_nodes_index + i;
        let latter_index = latter_boundary_nodes_index + i;

        var former_node_cast = vec2u(0, 0);
        if (i < former_boundary_data.y) { former_node_cast = bitcast<vec2u>(entity_nodes[former_index]); }
        var latter_node_cast = vec2u(0, 0);
        if (i < latter_boundary_data.y) { latter_node_cast = bitcast<vec2u>(entity_nodes[latter_index]); }

        let former_node_packed = vec2f8(former_node_cast);
        let latter_node_packed = vec2f8(latter_node_cast);
        private_entity_nodes[i] =
            (former_node_packed.x & 0xFFu) + ((former_node_packed.y & 0xFFu) << 8) +
            (latter_node_packed.x & 0xFFu) + ((latter_node_packed.y & 0xFFu) << 8) << 16;
    }

    node_meta = boundary_count_max;
}

// E4M3 without NaN because :) precision doesn't grow on trees kiddo
fn vec2f8(casted_vec2f : vec2u) -> vec2u {
    let mantissa = (casted_vec2f >> vec2u(20, 20)) & vec2u(0x7u, 0x7u);
    let exponent = ((casted_vec2f >> vec2u(23, 23)) & vec2u(0xFFu, 0xFFu) - vec2u(120, 120));

    return
        mantissa +
        (exponent << vec2u(3, 3)) +
        (casted_vec2f & vec2u(0x80000000u, 0x80000000u));
}