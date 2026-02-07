
// entity block

// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

struct DataStruct_block {
    node_count: u32,
    nodes: array<vec2f, 4>,
    mass: u32
}

const EntityData_block = DataStruct_block(
    4,
    array(
        vec2f(-8, 8),
        vec2f(8, 8),
        vec2f(8, -8),
        vec2f(-8, -8)
    ),
    100
);

fn main_block(index : u32, index_in_buffer : u32) {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == global_invocation_id.x) {
        control_block(player_index);
    }
}

fn control_block(index_in_buffer : u32, player_index : u32) {
    let w_pressed = get_bit_from_input(base_input_integer_sub_divisions.w);
    let a_pressed = get_bit_from_input(base_input_integer_sub_divisions.a);
    let s_pressed = get_bit_from_input(base_input_integer_sub_divisions.s);
    let d_pressed = get_bit_from_input(base_input_integer_sub_divisions.d);

    let dir_vec = vec2i(
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );

    let new_x = get_x_vel() + f32(dir_vec.x);
    let new_y = get_y_vel() + f32(dir_vec.y);
}

fn handle_collision_block(collider : u32) {
    // john dies
}