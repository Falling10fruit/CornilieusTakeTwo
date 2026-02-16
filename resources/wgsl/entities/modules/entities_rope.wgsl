// entity rope

// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

struct DataStruct_rope {
    node_count: u32,
    nodes: array<vec2f, 4>,
    mass: u32
}

const EntityData_rope = DataStruct_rope(
    4, // for the for loops to know how many times to loop automatically in the physics function
    array(
        vec2f(-0.5, 1.0),
        vec2f(0.5, 1.0),
        vec2f(0.5, -1.0),
        vec2f(-0.5, -1.0),
    ),
    2 // in kilograms
);

fn main_rope() {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == entity_index) {
        control_rope();
    }
}

fn control_rope() {
    let w_pressed = get_bit_from_input(base_input_integer_sub_divisions.w[0]);
    let a_pressed = get_bit_from_input(base_input_integer_sub_divisions.a[0]);
    let s_pressed = get_bit_from_input(base_input_integer_sub_divisions.s[0]);
    let d_pressed = get_bit_from_input(base_input_integer_sub_divisions.d[0]);

    let dir_vec = vec2i(
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );

    let new_x = get_x_vel() + f32(dir_vec.x);
    let new_y = get_y_vel() + f32(dir_vec.y);
}

fn handle_collision_rope(collider : u32) {
    // rope dies
}