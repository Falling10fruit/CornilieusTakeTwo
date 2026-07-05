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
//    01010101     01010101    01010101            0101010 1 <- flag for collision found, moving on to epa
// w                                                        
// boundary id 1 boundary id 2 boundary id 3    wow so cool
//    01010101     01010101    01010101            0101010 1 <- flag for no collision detected

fn cross2d(a: vec2f, b: vec2f) -> f32 { return a.x * b.y - a.y * b.x; }
fn cross2d_vec_scalar(a: vec2f, b: f32) -> vec2f { return vec2f(b * a.y, -b * a.x); }

struct SupportNode {
    pos: vec2f,
    former_id: u32,
    latter_id: u32
}

var<private> node_meta : u32;
var<private> private_entity_nodes : array<u32, 16>;
var<private> center_delta : vec2f;

// 64 * 512 (for a total of 2^24 threads)
// the y direction will be used to scale the algorithm
@compute @workgroup_size(128) fn setup_collision_nodes( // TODO high thread count because we want to store entity node data into local memory
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

    load_entity_nodes(former_boundary_id, former_type_id, latter_boundary_id, latter_type_id);

    center_delta = vec2f(
        bitcast<vec2i>(entities_buffer_meta[index_offset + latter_collider_id].zw) - 
        bitcast<vec2i>(entities_buffer_meta[index_offset + former_collider_id].zw)
    ) / 64.0;
    let direction_0 = -center_delta;
        
    let support_node_0 = support_function(direction_0);

    let direction_1 = -support_node_0.pos;

    let support_node_1 = support_function(direction_1);
    if (dot(support_node_1.pos, direction_1) < 0) { return; }

    let support_01_delta = support_node_1.pos - support_node_0.pos;
    let direction_2 = cross2d_vec_scalar(support_01_delta, cross2d(-support_node_0.pos, support_01_delta));

    let support_node_2 = support_function(direction_2);
    if (dot(support_node_2.pos, direction_2) < 0) { return; }

    let support_02_delta = support_node_2.pos - support_node_0.pos;
    let voronoi_normal_0 = cross2d_vec_scalar(support_02_delta, cross2d(support_02_delta, -support_node_0.pos));
    let support_12_delta = support_node_2.pos - support_node_0.pos;
    let voronoi_normal_1 = cross2d_vec_scalar(support_12_delta, cross2d(support_12_delta, -support_node_0.pos));

    let voronoi_dot_0 = dot(voronoi_normal_0, -support_node_2.pos);
    let voronoi_dot_1 = dot(voronoi_normal_1, -support_node_2.pos);
    if (
        voronoi_dot_0 < 0 &&
        voronoi_dot_1 < 0
    ) {
        entities_buffer_1[global_index].z |= 1u;
        return; 
    }

    for (var i = 0; i < 7; i++) { // I considered 6 btw
        let direction = select(voronoi_normal_0, voronoi_normal_1, voronoi_dot_0 < 0);
        let former_node = support_function(former_type_id, direction);
        let latter_node = support_function(direction);
    }
}

// gjk_bounds_dictionary_pointer
//    \/                                 ----------------------   ------------------------
//  (0, 3), (3, 4), (7, 5), (12, 4), (2, 3), (4, 6), (-3, -5), (3, 1), (-4, 5), (-2, -1)
//  \-----------------------------/
//          gjk_bounds_count

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
        if (i < former_boundary_data.y) { former_node_cast = bitcast<u32>(entity_nodes[former_index]); }
        var latter_node_cast = vec2u(0, 0);
        if (i < latter_boundary_data.y) { latter_node_cast = bitcast<u32>(entity_nodes[latter_index]); }

        // E4M3 without NaN because :) precision doesn't grow on trees kiddo
        let former_node_mantissa = (former_node_cast >> vec2u(20, 20)) & vec2u(0x7u, 0x7u);
        let former_node_exponent = ((former_node_cast >> vec2u(23, 23)) & vec2u(0xFFu, 0xFFu) - vec2u(120, 120));
        let former_node_packed =
            former_node_mantissa +
            (former_node_exponent << vec2u(3, 3)) +
            (former_node_cast & vec2u(0x80000000u, 0x80000000u));

        let latter_node_mantissa = (latter_node_cast >> vec2u(20, 20)) & vec2u(0x7u, 0x7u);
        let latter_node_exponent = ((latter_node_cast >> vec2u(23, 23)) & vec2u(0xFFu, 0xFFu) - vec2u(120, 120));
        let latter_node_packed =
            latter_node_mantissa +
            (latter_node_exponent << vec2u(3, 3)) +
            (latter_node_cast & vec2u(0x80000000u, 0x80000000u));

        private_entity_nodes[i] =
            (former_node_packed.x & 0xFFu) + ((former_node_packed.y & 0xFFu) << 8) +
            (latter_node_packed.x & 0xFFu) + ((latter_node_packed.y & 0xFFu) << 8) << 16;
    }

    node_meta = boundary_count_max;
}