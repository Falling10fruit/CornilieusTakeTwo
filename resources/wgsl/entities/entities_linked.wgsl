// 
//    Entity index (creation order)
// 01010101 01010101 01010101 01010101
// type (2^9 = 512) chunk index 2^16   xPos(2^13)    yPos (16 * 8 pixels divided by 2^13) rotation 2^13 
//    010101010     1010101010101010 1010101 010101           0101010101010               1010101010101
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101
// 2^10 -> 1023          2^12 -> 4095
struct BaseIntegerSubDivisions {
    entity_type: vec2u,
    chunk: vec2u,
    x_position: vec2u,
    y_position: vec2u,
    rotation: vec2u,
    x_velocity: vec2u,
    y_velocity: vec2u,
    rotation_velocity: vec2u,
}

const base_integer_sub_divisions = BaseIntegerSubDivisions(
    vec2u(0, 8),
    vec2u(9, 24),
    vec2u(25, 37),
    vec2u(38, 50),
    vec2u(51, 63),
    vec2u(64, 73),
    vec2u(74, 83),
    vec2u(84, 95),
);


// chunk indicies descriptor
// index of access is index of chunk, returned u32 is index of first entity in chunk

const NO_OF_INTEGERS_PER_ENTITY : u32 = 7;
alias EntityIntegers = array<u32, NO_OF_INTEGERS_PER_ENTITY>;

@group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer : array<u32>;

var<private> chunk_x : u32;
var<private> chunk_y : u32;
var<private> sub_chunk_index : u32;
var<private> entity_index_position : vec3u;
var<private> entity_integers : EntityIntegers;
var<private> entity_type : u32;

fn get_sub_integer (range : vec2u, integers : EntityIntegers) -> u32 {
    let lower_sector = range.x / 32;
    let upper_sector = range.y / 32;
    let lower_sub_position = range.x % 32;
    let upper_sub_position = range.y % 32;
    let lower_mask_offset = lower_sub_position;
    let upper_mask_offset = (32 - upper_sub_position);

    var sub_integer = 0;

    let stride = upper_sector - lower_sector;
    for (var i = 0; i < stride; i++) {
        var lower_bit_mask : u32 = 0xFFFFFFFF;
        var upper_bit_mask : u32 = 0xFFFFFFFF;
        if (i == 0         ) { lower_bit_mask = lower_bit_mask >> lower_mask_offset; }
        if (i == stride - 1) { upper_bit_mask = upper_bit_mask << upper_mask_offset; }
        var bit_mask : u32 = 0xFFFFFFFF & lower_bit_mask & upper_bit_mask;

        sub_integer += integers[lower_sector + i] & bit_mask;
    }

    return sub_integer;
}

// Using groups because I'm too lazy to offset everything when i insert something new
@group(1) @binding(0) var<storage, read_write> sprites_target : array<u32>;

// First index is player count    qwe asd zxc rfv 1234  mouse_left mouse_middle mouse_left mouse rotation = 2^13 = ?? degrees
//                                010 101 010 101 0101  0          1            0          10101 01010101
// Chat agrees that this should be a storage buffer, calm down yoga - 7 dec 2025
@group(2) @binding(0) var<storage, read> players_input : array<u32>;

fn get_x_vel (integers : EntityIntegers) {
    let raw_int = get_sub_integer(base_integer_sub_divisions.x_velocity, integers);
    let sign_bit = raw_int >> 9;
    let sign = i32(sign_bit * 2) - 1;
    
}
fn get_y_vel (integers : EntityIntegers) {
    let raw_int = get_sub_integer(base_integer_sub_divisions.y_velocity, integers);
    let sign_bit = raw_int >> 9;
    let sign = i32(sign_bit * 2) - 1;
    
}

fn get_rotation_vel (integers : EntityIntegers) {
    return get_sub_integer(base_integer_sub_divisions.rotation_velocity, integers);
}

@compute @workgroup_size(64, 1, 1) fn cShader(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    if (global_invocation_id >= arrayLength(entities_buffer)) { return; }

    chunk_x = workgroup_id.x;
    chunk_y = workgroup_id.y;
    sub_chunk_index = workgroup_id.z;
    entity_index_position = workgroup_id * vec3u(1, 1, 14);
    for (var i = 0; i < NO_OF_INTEGERS_PER_ENTITY; i++) { entity_integers[i] = entities_buffer[global_invocation_id.x * 7]; }
    entity_type = (integers[1] >> 23) & 511;

// else
    if (entity_type == 0) { main_john(); } else
    if (entity_type == 1) { main_block(); } else
    if (entity_type == 2) { main_drill(); } else
    if (entity_type == 3) { main_rope(); }

    do_the_physics();
} 

fn do_the_physics(index : u32, index_in_buffer : u32, integers : array<u32, 8>) {
    // if (entity_type == 1) {
    //     // main_john(index, index_in_buffer);
    // }
}


fn handle_collision(entity_type : u32, collider: u32) {
// else
    if (entity_type == 0) { handle_collision_john(collider); } else
    if (entity_type == 1) { handle_collision_block(collider); } else
    if (entity_type == 2) { handle_collision_drill(collider); } else
    if (entity_type == 3) { handle_collision_rope(collider); }
}// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

struct DataStruct_john {
    node_count: u32,
    nodes: array<vec2f, 11>,
    mass: u32
}

const EntityData_john = DataStruct_john(
    11, // for the for loops to know how many times to loop automatically in the physics function
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
);

fn main_john(index : u32, index_in_buffer : u32) {
    let player_count = players_input[0];

    var player_index = -1;
    for (var i = 0; i < player_count; i++) {
        let selected_index = players_input[i * 2 + 1];

        if (selected_index == index) {
            player_index = true;
            break;
        }
    }

    if (player_index != -1) {
        control_john(player_index);
    }
}

fn control_john(index_in_buffer : u32, player_index : u32) {
    let input_u32 = players_input[player_index * 2 + 2];
    let w_pressed = (input_u32 >> (16 + 13)) & 4;
    let a_pressed = (input_u32 >> (16 + 10)) & 4;
    let s_pressed = (input_u32 >> (16 + 10)) & 2;
    let d_pressed = (input_u32 >> (16 + 10)) & 1;

    let dir_vec = vec2i(
        d_pressed - a_pressed,
        w_pressed - s_pressed,
    );

    // let current_xVel = get_index_from_entity_buffer[index_in_buffer * 8 + 0] >> ; Man everytime I need the book I don't have it

    let first_int = get_index_from_entity_buffer(index_in_buffer * 8 + 0);
    let second_int = get_index_from_entity_buffer(index_in_buffer * 8 + 1);
    let third_int = get_index_from_entity_buffer(index_in_buffer * 8 + 2);

    let current_x_position = (*first_int >> 11) & 16383;
    let current_y_position_first_part = *first_int & 2047;
    let current_y_position_second_part = (second_int >> 29) & 7;
    let current_y_position = current_y_position_first_part << 3 + current_y_position_second_part;
    let current_position = vec2i(current_x_position, current_y_position);
    let new_position = current_position + dir_vec;
    
}

fn handle_collision_john(collider : u32) {
    // john dies
}// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
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
    nodes: array<vec2f, 11>,
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
    let player_count = players_input[0];

    var player_index = -1;
    for (var i = 0; i < player_count; i++) {
        let selected_index = players_input[i * 2 + 1];

        if (selected_index == index) {
            player_index = true;
            break;
        }
    }

    if (player_index != -1) {
        control_block(player_index);
    }
}

fn control_block(index_in_buffer : u32, player_index : u32) {
    let input_u32 = players_input[player_index * 2 + 2];
    let w_pressed = (input_u32 >> (16 + 13)) & 4;
    let a_pressed = (input_u32 >> (16 + 10)) & 4;
    let s_pressed = (input_u32 >> (16 + 10)) & 2;
    let d_pressed = (input_u32 >> (16 + 10)) & 1;

    let dir_vec = vec2i(
        d_pressed - a_pressed,
        w_pressed - s_pressed,
    );

    // let current_xVel = get_index_from_entity_buffer[index_in_buffer * 8 + 0] >> ; Man everytime I need the book I don't have it

    let first_int = get_index_from_entity_buffer(index_in_buffer * 8 + 0);
    let second_int = get_index_from_entity_buffer(index_in_buffer * 8 + 1);
    let third_int = get_index_from_entity_buffer(index_in_buffer * 8 + 2);

    let current_x_position = (*first_int >> 11) & 16383;
    let current_y_position_first_part = *first_int & 2047;
    let current_y_position_second_part = (second_int >> 29) & 7;
    let current_y_position = current_y_position_first_part << 3 + current_y_position_second_part;
    let current_position = vec2i(current_x_position, current_y_position);
    let new_position = current_position + dir_vec;
    
}

fn handle_collision_block(collider : u32) {
    // john dies
}// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

struct DataStruct_john {
    node_count: u32,
    nodes: array<vec2f, 11>,
    mass: u32
}

const EntityData_john = DataStruct_john(
    11, // for the for loops to know how many times to loop automatically in the physics function
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
);

fn main_john(index : u32, index_in_buffer : u32) {
    let player_count = players_input[0];

    var player_index = -1;
    for (var i = 0; i < player_count; i++) {
        let selected_index = players_input[i * 2 + 1];

        if (selected_index == index) {
            player_index = true;
            break;
        }
    }

    if (player_index != -1) {
        control_john(player_index);
    }
}

fn control_john(index_in_buffer : u32, player_index : u32) {
    let input_u32 = players_input[player_index * 2 + 2];
    let w_pressed = (input_u32 >> (16 + 13)) & 4;
    let a_pressed = (input_u32 >> (16 + 10)) & 4;
    let s_pressed = (input_u32 >> (16 + 10)) & 2;
    let d_pressed = (input_u32 >> (16 + 10)) & 1;

    let dir_vec = vec2i(
        d_pressed - a_pressed,
        w_pressed - s_pressed,
    );

    // let current_xVel = get_index_from_entity_buffer[index_in_buffer * 8 + 0] >> ; Man everytime I need the book I don't have it

    let first_int = get_index_from_entity_buffer(index_in_buffer * 8 + 0);
    let second_int = get_index_from_entity_buffer(index_in_buffer * 8 + 1);
    let third_int = get_index_from_entity_buffer(index_in_buffer * 8 + 2);

    let current_x_position = (*first_int >> 11) & 16383;
    let current_y_position_first_part = *first_int & 2047;
    let current_y_position_second_part = (second_int >> 29) & 7;
    let current_y_position = current_y_position_first_part << 3 + current_y_position_second_part;
    let current_position = vec2i(current_x_position, current_y_position);
    let new_position = current_position + dir_vec;
    
}

fn handle_collision_john(collider : u32) {
    // john dies
}// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

struct DataStruct_john {
    node_count: u32,
    nodes: array<vec2f, 11>,
    mass: u32
}

const EntityData_john = DataStruct_john(
    11, // for the for loops to know how many times to loop automatically in the physics function
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
);

fn main_john(index : u32, index_in_buffer : u32) {
    let player_count = players_input[0];

    var player_index = -1;
    for (var i = 0; i < player_count; i++) {
        let selected_index = players_input[i * 2 + 1];

        if (selected_index == index) {
            player_index = true;
            break;
        }
    }

    if (player_index != -1) {
        control_john(player_index);
    }
}

fn control_john(index_in_buffer : u32, player_index : u32) {
    let input_u32 = players_input[player_index * 2 + 2];
    let w_pressed = (input_u32 >> (16 + 13)) & 4;
    let a_pressed = (input_u32 >> (16 + 10)) & 4;
    let s_pressed = (input_u32 >> (16 + 10)) & 2;
    let d_pressed = (input_u32 >> (16 + 10)) & 1;

    let dir_vec = vec2i(
        d_pressed - a_pressed,
        w_pressed - s_pressed,
    );

    // let current_xVel = get_index_from_entity_buffer[index_in_buffer * 8 + 0] >> ; Man everytime I need the book I don't have it

    let first_int = get_index_from_entity_buffer(index_in_buffer * 8 + 0);
    let second_int = get_index_from_entity_buffer(index_in_buffer * 8 + 1);
    let third_int = get_index_from_entity_buffer(index_in_buffer * 8 + 2);

    let current_x_position = (*first_int >> 11) & 16383;
    let current_y_position_first_part = *first_int & 2047;
    let current_y_position_second_part = (second_int >> 29) & 7;
    let current_y_position = current_y_position_first_part << 3 + current_y_position_second_part;
    let current_position = vec2i(current_x_position, current_y_position);
    let new_position = current_position + dir_vec;
    
}

fn handle_collision_john(collider : u32) {
    // john dies
}