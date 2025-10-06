// 
//    Entity index (creation order)
// 01010101 01010101 01010101 01010101
// type (2^9 = 512)   xPos(2^14)  yPos (127.99)
//    010101010     1010101010101 010101010101  010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101

// chunk indicies descriptor
// index of access is index of chunk, returned u32 is index of first entity in chunk
// Bokura no Libido
// 601310 different

@group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
@group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

@group(1) @binding(0) var<storage, read_write> sprites_target : array<u32>;

struct Entity {
    nodes: array<vec2f>,
    mass: u32
}

const AMOUNT_OF_ENTITY_TYPES = 1;
const ENTITY_TYPES : array<Entity, AMOUNT_OF_ENTITY_TYPES> = array(
    Entity(
        array(
            vec2f(-2.5, 7.5),
            vec2f(2.5, 7.5),
            vec2f(3.5, 0.5),
            vec2f(4.5, -0.5),
            vec2f(2.5, -0.5),
            vec2f(2.5, -7.5),
            vec2f(-3.5, -7.5),
            vec2f(-3.5, -1.5),
            vec2f(-4.5, -1.5),
            vec2f(-4.5, 0.5),
            vec2f(-2.5, 2.5),
        ),
        60 // in kilograms
    )
);

fn get_entity_by_index(index : u32) -> u32 {
    return select(
        entities_buffer_0[index],
        entities_buffer_1[index],
        current_entity_buffer_is == 0
    );
}

@compute @workgroup_size(16, 16, 1) fn cShader(
    @builtin(global_invocation_id) index_vec_3 : vec3u,
    @builtin(num_workgroups) dispatch_size : vec3u,
) {
    let index = index_vec_3.x + index_vec_3.y * dispatch_size.x * 16;
    let index_in_buffer = entities_indicies[index];

    var integers : array<u32, 8>;
    for (var i = 0; i < 8; i++) { integers[i] = get_entity_by_index(index_in_buffer + i); }

    do_the_physics(index, index_in_buffer, integers);
} 

fn do_the_physics(index : u32, index_in_buffer : u32, integers : array<u32, 8>) {
    let entity_type : u32 = (integers[1] >> 23) & 511;
    if (entity_type == 1) {

    }
}