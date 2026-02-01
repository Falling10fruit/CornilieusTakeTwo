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

const pow2 = array<u32, 32>(1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216);

// chunk indicies descriptor
// index of access is index of chunk, returned u32 is index of first entity in chunk

const NO_OF_INTEGERS_PER_ENTITY : u32 = 7;
alias EntityIntegers = array<u32, NO_OF_INTEGERS_PER_ENTITY>;

@group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_0 : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_1 : array<u32>;

var<private> chunk_x : u32;
var<private> chunk_y : u32;
var<private> sub_chunk_index : u32;
var<private> entity_index_position : vec3u;
var<private> entity_integers : EntityIntegers;
var<private> entity_type : u32;

fn shift_left (value : u32, shift: u32) -> u32 {
    return select(value << shift, 0, shift >= 32);
}

fn shift_right (value : u32, shift: u32) -> u32 {
    return  select(value >> shift, 0, shift >= 32);
}

fn get_sub_integer (range : vec2u) -> u32 {
    var sub_integer = 0;
    for (var i : u32 = range.x / 32; i < range.y / 32; i++) {
        let offset : u32 = i * 32;
        let mask_start : u32 = clamp(0, 32, range.x - offset);
        let mask_end : i32 = 31 - i32(range.x) + i32(offset);
        let bit_mask_start = shift_right(0xFFFFFFFF, clamp(0, 32, mask_start));
        let bit_mask_end = shift_left(0xFFFFFFFF, u32(clamp(0, 32, mask_end)));
        let masked_integer = entity_integers[i] & bit_mask_start & bit_mask_end;

        if (mask_end < 0) {
            sub_integer += masked_integer << u32(-mask_end);
        } else {
            sub_integer += masked_integer >> u32(mask_end);
        }
    }

    return sub_integer;
}

fn set_sub_integer(range : vec2u, new_value : u32) {
    for (let i = 0; i < range.y; i += 32) {
        let offset : u32 = i * 32;

        let mask_start : i32 = 32 - i32(range.x) + i32(offset);
        let mask_end = 1 + (range.x - offset);
        
        let bit_mask_start = shift_left(0xFFFFFFFF, u32(clamp(0, 32, mask_start)));
        let bit_mask_end = shift_right(0xFFFFFFFF, clamp(0, 32, mask_end));
        
        let masked_int = entity_integers[i] & (bit_mask_start | bit_mask_end);
        let value_shift = i32(mask_end) - 32;

        entity_integers[i] = masked_int + select(shift_left(new_value, u32(-value_shift)), shift_right(new_value, u32(value_shift)), value_shift > 0);
    }
}

// Using groups because I'm too lazy to offset everything when i insert something new
@group(1) @binding(0) var<storage, read_write> sprites_target : array<u32>;

// First index is player count    qwe asd zxc rfv 1234  mouse_left mouse_middle mouse_left mouse rotation = 2^13 = ?? degrees
//                                010 101 010 101 0101  0          1            0          10101 01010101
// Chat agrees that this should be a storage buffer, calm down yoga - 7 dec 2025
@group(2) @binding(0) var<storage, read> players_input : array<u32>;

// sign exponent mantissa
//  0      10     1010101
fn get_x_vel () -> f32 {
    let raw_int = get_sub_integer(base_integer_sub_divisions.x_velocity);
    let sign_bit = raw_int >> 9;
    let sign : f32 = f32(sign_bit * 2) - 1.0; // 0 - 1 -> -1 - 1

    let exponent_int = (raw_int >> 7) & 3;
    let exponent_multiplier : f32 = pow(10.0, f32(exponent_int));
    
    return sign * exponent_multiplier * f32(raw_int & 127);
}

fn set_x_vel (vel : f32) {
    let sign = select(1, 0, vel < 0);
    let abs_vel = abs(vel);
    let power = floor(log2(abs_vel/128) * 0.69314718) + 1.0; // log2(x) / log2(10)
    let mantissa : u32 = u32(round(abs_vel / pow(10.0, power)));
    
    let sub_integer = (clamp(0, 1, sign) << 9) + (clamp(0, 3, power) << 7) + clamp(0, 127, mantissa);
    set_sub_integer(base_integer_sub_divisions.x_velocity, sub_integer)
}

fn get_y_vel () -> f32 {
    let raw_int = get_sub_integer(base_integer_sub_divisions.y_velocity);
 
    let sign_bit = raw_int >> 9;
    let sign : f32 = f32(sign_bit * 2) - 1.0;

    let exponent_int = (raw_int >> 7) & 3;
    let exponent_multiplier : f32 = pow(10.0, f32(exponent_int));
    
    return sign * exponent_multiplier * f32(raw_int & 127);
}

// 0 10 101010101
fn get_rotation_vel () -> f32 {
    let raw_int = get_sub_integer(base_integer_sub_divisions.rotation_velocity);

    let sign_bit = raw_int >> 11;
    let sign : f32 = f32(sign_bit * 2) - 1.0;

    let exponent_int = (raw_int >> 9) & 3;
    let exponent_multiplier : f32 = pow(10.0, f32(exponent_int));
    
    return sign * exponent_multiplier * f32(raw_int & 511);
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

fn do_the_physics(index : u32, index_in_buffer : u32) {
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
}// entity john

// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
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
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );

    let new_x = get_x_vel(entity_integers) + f32(dir_vec.x);
    let new_y = get_y_vel(entity_integers) + f32(dir_vec.y);
}

fn handle_collision_john(collider : u32) {
    // john dies
}
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
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );

    let new_x = get_x_vel(entity_integers) + f32(dir_vec.x);
    let new_y = get_y_vel(entity_integers) + f32(dir_vec.y);
}

fn handle_collision_block(collider : u32) {
    // john dies
}// entity drill

// @group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
// @group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
// @group(0) @binding(2) var<storage, read_write> current_entity_buffer_is : u32;
// @group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<u32>;
// @group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<u32>;

// @group(0) @binding(5) var<storage, read_write> sprites_target : array<u32>;

// first index is player count   entitiy currently controlled by player   qwe asd zxc rfv 1234  mouse rotation = 2^16 = 65536 degrees
//                                 01010101010101010101010101010101       010 101 010 101 0101            01010101 01010101
// @group(0) @binding(6) var<storage, read> players_input : array<u32>;

struct DataStruct_drill {
    node_count: u32,
    nodes: array<vec2f, 11>,
    mass: u32
}

const EntityData_drill = DataStruct_drill(
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

fn main_drill(index : u32, index_in_buffer : u32) {
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
        control_drill(player_index);
    }
}

fn control_drill(index_in_buffer : u32, player_index : u32) {
    let input_u32 = players_input[player_index * 2 + 2];
    let w_pressed = (input_u32 >> (16 + 13)) & 4;
    let a_pressed = (input_u32 >> (16 + 10)) & 4;
    let s_pressed = (input_u32 >> (16 + 10)) & 2;
    let d_pressed = (input_u32 >> (16 + 10)) & 1;

    let dir_vec = vec2i(
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );
    
    let new_x = get_x_vel(entity_integers) + f32(dir_vec.x);
    let new_y = get_y_vel(entity_integers) + f32(dir_vec.y);
}

fn handle_collision_drill(collider : u32) {
    // drill dies
}// entity rope

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
    for (var i = 0; i < player_count; i++) {
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

    let new_x = get_x_vel(entity_integers) + f32(dir_vec.x);
    let new_y = get_y_vel(entity_integers) + f32(dir_vec.y);
}

fn handle_collision_rope(collider : u32) {
    // rope dies
}