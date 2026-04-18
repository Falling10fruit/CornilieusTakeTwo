// entity drill

// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

const nodes_drill: array<vec2f, 10> = array(
    vec2f(-2.0, 4.0),
    vec2f(1.0, 4.0),
    vec2f(2.0, 3.0),
    vec2f(2.0, -2.0),
    vec2f(1.0, -3.0),
    vec2f(0.0, -3.0),
    vec2f(0.0, -7.0),
    vec2f(-1.0, -7.0),
    vec2f(-1.0, -3.0),
    vec2f(-2.0, -2.0),
);

fn main_drill() {
}

fn handle_collision_drill(collider : u32) {
    // drill dies
}