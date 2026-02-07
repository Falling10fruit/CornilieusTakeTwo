// 
//    Entity index (creation order)
// 01010101 01010101 01010101 01010101
// type (2^9 = 512) chunk index 2^16   xPos(2^13)    yPos (16 * 8 pixels divided by 2^13) rotation 2^13 
//    010101010     1010101010101010 1010101 010101           0101010101010               1010101010101
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101
// 2^10 -> 1023          2^12 -> 4095
struct sub_division_entry {
    start : u32,
    end : u32,
    prefix_sum : u32,
}
struct BaseEntityIntegerSubDivisions {
    entity_type: vec2u,
    chunk: vec2u,
    x_position: vec2u,
    y_position: vec2u,
    rotation: vec2u,
    x_velocity: vec2u,
    y_velocity: vec2u,
    rotation_velocity: vec2u,
}

const base_entity_integer_sub_divisions = BaseEntityIntegerSubDivisions(
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
@group(0) @binding(2) var<storage, read_write> entities_buffer_0 : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_1 : array<u32>;

var<private> chunk_x : u32;
var<private> chunk_y : u32;
var<private> sub_chunk_index : u32;
var<private> entity_integers : EntityIntegers;
var<private> entity_type : u32;

fn shift_left (value : u32, shift: u32) -> u32 {
    return select(value << shift, 0, shift >= 32);
}

fn shift_right (value : u32, shift: u32) -> u32 {
    return  select(value >> shift, 0, shift >= 32);
}

fn get_sub_integer_entity(range : vec2u) -> u32 {
    var sub_integer : u32 = 0;
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

fn set_sub_integer_entity(range : vec2u, new_value : u32) {
    for (var i : u32 = 0; i < range.y; i += 32) {
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

// sign exponent mantissa
//  0      10     1010101
fn get_x_vel () -> f32 {
    let raw_int = get_sub_integer_entity(base_entity_integer_sub_divisions.x_velocity);
    let sign_bit = raw_int >> 9;
    let sign : f32 = f32(sign_bit * 2) - 1.0; // 0 - 1 -> -1 - 1

    let exponent_int = (raw_int >> 7) & 3;
    let exponent_multiplier : f32 = pow(10.0, f32(exponent_int));
    
    return sign * exponent_multiplier * f32(raw_int & 127);
}

fn set_x_vel (vel : f32) {
    let sign = u32(select(1, 0, vel < 0));
    let abs_vel = abs(vel);
    let power = floor(log2(abs_vel/128) * 0.69314718) + 1.0; // log2(x) / log2(10)
    let mantissa : u32 = u32(round(abs_vel / pow(10.0, power)));
    
    let sub_integer = (clamp(0, 1, sign) << 9) + (clamp(0, 3, u32(round(power))) << 7) + clamp(0, 127, mantissa);
    set_sub_integer_entity(base_entity_integer_sub_divisions.x_velocity, sub_integer);
}

fn get_y_vel () -> f32 {
    let raw_int = get_sub_integer_entity(base_entity_integer_sub_divisions.y_velocity);
 
    let sign_bit = raw_int >> 9;
    let sign : f32 = f32(sign_bit * 2) - 1.0;

    let exponent_int = (raw_int >> 7) & 3;
    let exponent_multiplier : f32 = pow(10.0, f32(exponent_int));
    
    return sign * exponent_multiplier * f32(raw_int & 127);
}

fn set_y_vel (vel : f32) {
    let sign = u32(select(1, 0, vel < 0));
    let abs_vel = abs(vel);
    let power = floor(log2(abs_vel/128) * 0.69314718) + 1.0; // log2(x) / log2(10)
    let mantissa : u32 = u32(round(abs_vel / pow(10.0, power)));
    
    let sub_integer = (clamp(0, 1, sign) << 9) + (clamp(0, 3, u32(round(power))) << 7) + clamp(0, 127, mantissa);
    set_sub_integer_entity(base_entity_integer_sub_divisions.y_velocity, sub_integer);
}

// 0 10 101010101
fn get_rotation_vel () -> f32 {
    let raw_int = get_sub_integer_entity(base_entity_integer_sub_divisions.rotation_velocity);

    let sign_bit = raw_int >> 11;
    let sign : f32 = f32(sign_bit * 2) - 1.0;

    let exponent_int = (raw_int >> 9) & 3;
    let exponent_multiplier : f32 = pow(10.0, f32(exponent_int));
    
    return sign * exponent_multiplier * f32(raw_int & 511);
}

// Using groups because I'm too lazy to offset everything when i insert something new
@group(1) @binding(0) var<storage, read_write> sprites_target : array<u32>;

// First index is player count   controlled entity's index   qwe asd zxc rfv tgb yhn tab shift ctrl alt 0123456789  mouse_left mouse_middle mouse_right mouse rotation = 2^13 = ?? degrees mouse x      mouse y
//                               010101010101010101010101    010 101 010 101 010 101 0   1     0    1   0101010101  0          1            0           10101 01010101                     010101010101 010101010101
// Chat agrees that this should be a storage buffer, calm down yoga - 7 dec 2025
@group(2) @binding(0) var<storage, read> players_input : array<u32>;

const NO_OF_INTEGERS_PER_INPUT : u32 = 2;
alias InputIntegers = array<u32, NO_OF_INTEGERS_PER_INPUT>;
struct BaseInputIntegerSubDivisions {
    entity_id : vec2u,
    q : vec2u,
    w : vec2u,
    e : vec2u,
    a : vec2u,
    s : vec2u,
    d : vec2u,
    z : vec2u,
    x : vec2u,
    c : vec2u,
    r : vec2u,
    f : vec2u,
    v : vec2u,
    t : vec2u,
    g : vec2u,
    b : vec2u,
    y : vec2u,
    h : vec2u,
    n : vec2u,
    tab : vec2u,
    shift : vec2u,
    ctrl : vec2u,
    alt : vec2u,
    zero : vec2u,
    one : vec2u,
    two : vec2u,
    three : vec2u,
    four : vec2u,
    five : vec2u,
    six : vec2u,
    seven : vec2u,
    eight : vec2u,
    nine : vec2u,
    mouse_left : vec2u,
    mouse_middle : vec2u,
    mouse_right : vec2u,
    mouse_rotation : vec2u,
    mouse_x : vec2u,
    mouse_y : vec2u,
}
const base_input_integer_sub_divisions = BaseInputIntegerSubDivisions(
    vec2u(0, 23),  // entity id
    vec2u(24, 24), // q     For single bits like these, it's
    vec2u(25, 25), // w     better to use the get_bit_from_input
    vec2u(26, 26), // e     function instead of the 
    vec2u(27, 27), // a     get_sub_integer_input() function for
    vec2u(28, 28), // s     performance I think
    vec2u(29, 29), // d
    vec2u(30, 30), // z
    vec2u(31, 31), // x
    vec2u(32, 32), // c
    vec2u(33, 33), // r
    vec2u(34, 34), // f
    vec2u(35, 35), // v
    vec2u(36, 36), // t
    vec2u(37, 37), // g
    vec2u(38, 38), // b
    vec2u(39, 39), // y
    vec2u(40, 40), // h
    vec2u(41, 41), // n
    vec2u(42, 42), // tab
    vec2u(43, 43), // shift
    vec2u(44, 44), // ctrl
    vec2u(45, 45), // alt
    vec2u(46, 46), // 0
    vec2u(47, 47), // 1
    vec2u(48, 48), // 2
    vec2u(49, 49), // 3
    vec2u(50, 50), // 4
    vec2u(51, 51), // 5
    vec2u(52, 52), // 6
    vec2u(53, 53), // 7
    vec2u(54, 54), // 8
    vec2u(55, 55), // 9
    vec2u(56, 56), // mouse left
    vec2u(57, 57), // mouse middle
    vec2u(58, 58), // mouse right
    vec2u(59, 71), // mouse rotation
    vec2u(72, 83), // mouse x
    vec2u(84, 95), // mouse y
);
var<private> input_integers : InputIntegers;
var<private> is_controlled : bool;


fn get_sub_integer_input(range : vec2u) -> u32 {
    var sub_integer : u32 = 0;
    for (var i : u32 = range.x / 32; i < range.y / 32; i++) {
        let offset : u32 = i * 32;
        let mask_start : u32 = clamp(0, 32, range.x - offset);
        let mask_end : i32 = 31 - i32(range.x) + i32(offset);
        let bit_mask_start = shift_right(0xFFFFFFFF, clamp(0, 32, mask_start));
        let bit_mask_end = shift_left(0xFFFFFFFF, u32(clamp(0, 32, mask_end)));
        let masked_integer = input_integers[i] & bit_mask_start & bit_mask_end;

        if (mask_end < 0) {
            sub_integer += masked_integer << u32(-mask_end);
        } else {
            sub_integer += masked_integer >> u32(mask_end);
        }
    }

    return sub_integer;
}

fn get_bit_from_input(index : u32) -> u32 { // Use this to quickly get single digits
    return (players_input[index / 32] >> (31 - index % 32)) & 1u;
}

fn set_sub_integer_input(range : vec2u, new_value : u32) {
    for (var i : u32 = 0; i < range.y; i += 32) {
        let offset : u32 = i * 32;

        let mask_start : i32 = 32 - i32(range.x) + i32(offset);
        let mask_end = 1 + (range.x - offset);
        
        let bit_mask_start = shift_left(0xFFFFFFFF, u32(clamp(0, 32, mask_start)));
        let bit_mask_end = shift_right(0xFFFFFFFF, clamp(0, 32, mask_end));
        
        let masked_int = input_integers[i] & (bit_mask_start | bit_mask_end);
        let value_shift = i32(mask_end) - 32;

        input_integers[i] = masked_int + select(shift_left(new_value, u32(-value_shift)), shift_right(new_value, u32(value_shift)), value_shift > 0);
    }
}

fn get_input() { // replace this eventually pls with a dedicated shader. We don't have enough space in the entity_integers to fit a player id
    for (var i : u32; i < players_input[0]; i++) {
        let buffer_index = i * 2 + 1;
        let observed_entity_type = players_input[buffer_index] >> 8;

        if (observed_entity_type == entity_type) {
            for (var j : u32; j < NO_OF_INTEGERS_PER_INPUT; j++) {
                input_integers[j] = players_input[buffer_index + j];
            }
        }
    }
}

@compute @workgroup_size(64, 1, 1) fn cShader(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    if (global_invocation_id >= arrayLength(entities_buffer_0)) { return; }
    for (var i = 0; i < NO_OF_INTEGERS_PER_ENTITY; i++) { entity_integers[i] = entities_buffer_0[global_invocation_id.x * 7 + i]; }

    entity_type = (entity_integers[1] >> 23) & 511;
    get_input();


// else
    if (entity_type == 0) { main_john(); } else
    if (entity_type == 1) { main_block(); } else
    if (entity_type == 2) { main_drill(); } else
    if (entity_type == 3) { main_rope(); }

    do_the_physics();
} 

fn do_the_physics() {
    // if (entity_type == 1) {
    //     // main_john(index, index_in_buffer);
    // }
}


fn handle_collision(collider: u32) {
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
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == global_invocation_id.x) {
        control_john(player_index);
    }
}

fn control_john(index_in_buffer : u32, player_index : u32) {
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
    10, // for the for loops to know how many times to loop automatically in the physics function
    array(
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
    ),
    15 // in kilograms
);

fn main_drill(index : u32, index_in_buffer : u32) {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == global_invocation_id.x) {
        control_drill();
    }
}

fn control_drill() {
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
    4, // for the for loops to know how many times to loop automatically in the physics function
    array(
        vec2f(-0.5, 1.0),
        vec2f(0.5, 1.0),
        vec2f(0.5, -1.0),
        vec2f(-0.5, -1.0),
    ),
    2 // in kilograms
);

fn main_rope(index : u32, index_in_buffer : u32) {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == global_invocation_id.x) {
        control_rope(player_index);
    }
}

fn control_rope(index_in_buffer : u32, player_index : u32) {
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

fn handle_collision_rope(collider : u32) {
    // rope dies
}