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
    11, // for the for loops to know how many times to loop automatically in the physics function
    array(
        vec2f(-2.5, 7.5),
        vec2f(2.5, 7.5),
        vec2f(3.5, 0.5),
        vec2f(4.5, -0.5),
    ),
    60 // in kilograms
);

fn main_rope(index : u32, index_in_buffer : u32) {
    let player_count = players_input[0];

    var player_index = -1;
    for (var i : u32 = 0; i < player_count; i++) {
        let selected_index = players_input[i * 2 + 1];

        if (selected_index == index) {
            player_index = true;
            break;
        }
    }

    if (player_index != -1) {
        control_rope(player_index);
    }
}

fn control_rope(index_in_buffer : u32, player_index : u32) {
    let input_u32 = players_input[player_index * 2 + 2];
    let w_pressed = (input_u32 >> (16 + 13)) & 4;
    let a_pressed = (input_u32 >> (16 + 10)) & 4;
    let s_pressed = (input_u32 >> (16 + 10)) & 2;
    let d_pressed = (input_u32 >> (16 + 10)) & 1;

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