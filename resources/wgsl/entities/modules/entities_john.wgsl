// entity john

// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

const nodes_john: array<vec2f, 11> = array(
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
);

fn main_john() {
}

fn handle_collision_john(collider : u32) {
    // john dies
}