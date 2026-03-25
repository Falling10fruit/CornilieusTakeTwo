const pi = 3.1415926535; 
//    Entity index (creation order)
// 01010101 01010101 01010101 01010101
// type = 0 means no entity
// type (2^9 = 512)     chunk index 2^16         xPos(2^13)       yPos (16 * 8 pixels divided by 2^13)         rotation 2^13 
//  [ 01010101 0 ]   [ 1010101 01010101 0 ] [ 1010101 | 010101 ]           [ 01 01010101 010 ]              [ 10101 01010101 ] |
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 
// 2^10 -> 1023          2^12 -> 4095
//01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101
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
// index of access is index of chunk, the first 26 bits is the 
//                                  2^6 = 64
// 01010101 01010101 01010101 01 010101

@group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_0 : array<u32>;
alias points_to_entities_buffer_0 = ptr<storage, array<u32>, read_write>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_1 : array<u32>;
alias points_to_entities_buffer_1 = ptr<storage, array<u32>, read_write>;


// First index is player count   controlled entity's index   qwe asd zxc rfv tgb yhn tab shift ctrl alt 0123456789  mouse_left mouse_middle mouse_right mouse rotation = 2^13 = ?? degrees mouse x      mouse y
//                               010101010101010101010101    010 101 010 101 010 101 0   1     0    1   0101010101  0          1            0           10101 01010101                     010101010101 010101010101
// Chat agrees that this should be a storage buffer, calm down yoga - 7 dec 2025
@group(2) @binding(0) var<storage, read_write> debug_data : u32;
@group(2) @binding(1) var<storage, read>       players_input : array<u32>;
@group(2) @binding(2) var<uniform>             world_dimensions : vec2u;
@group(2) @binding(3) var<storage, read>       world_data : array<u32>;

const CHUNK_LENGTH : u32 = 8; // This is so that it can fit in the sprites
const NO_OF_INTEGERS_PER_ENTITY : u32 = 7;
alias EntityIntegers = array<u32, NO_OF_INTEGERS_PER_ENTITY>;
var<private> entity_integers : EntityIntegers;
var<private> entity_index : u32;
var<private> chunk_x : u32;
var<private> chunk_y : u32;
var<private> x_position : f32;
var<private> y_position : f32;
var<private> x_velocity : f32;
var<private> y_velocity : f32;
var<private> rotation : f32; // in the 2^13 format 0 - 8191
var<private> entity_type : u32;
var<private> current_sprite : u32;

fn shift_left (value : u32, shift: u32) -> u32 {
    return select(value << shift, 0, shift >= 32);
}

fn shift_right (value : u32, shift: u32) -> u32 {
    return  select(value >> shift, 0, shift >= 32);
}

fn get_sub_integer_entity(range : vec2u) -> u32 {
    var sub_integer : u32 = 0;
    for (var offset : u32 = 0; offset <= range.y; offset += 32) {
        let mask_start : u32 = u32(clamp(i32(range.x) - i32(offset), 0, 32));
        let mask_end : i32 = 31 - i32(range.y) + i32(offset);
        let bit_mask_start = shift_right(0xFFFFFFFFu, mask_start);
        let bit_mask_end = shift_left(0xFFFFFFFFu, u32(clamp(mask_end, 0, 32)));
        let masked_integer = entity_integers[offset / 32] & bit_mask_start & bit_mask_end;

        if (mask_end < 0) {
            sub_integer += shift_left(masked_integer, u32(-mask_end));
        } else {
            sub_integer += shift_right(masked_integer, u32(mask_end));
        }
    }

    return sub_integer;
}

fn set_sub_integer_entity(range : vec2u, new_value : u32) {
    for (var i : u32 = 0; i <= range.y; i += 32) {
        let offset : u32 = i * 32;

        let mask_start : i32 = 32 - i32(range.x) + i32(offset);
        let mask_end = 1 + (range.y - offset);
        
        let bit_mask_start = shift_left(0xFFFFFFFFu, u32(clamp(mask_start, 0, 32)));
        let bit_mask_end = shift_right(0xFFFFFFFFu, mask_end);
        
        let masked_int = entity_integers[i] & (bit_mask_start | bit_mask_end);
        let value_shift = i32(mask_end) - 32;

        entity_integers[i] = masked_int + select(shift_left(new_value, u32(-value_shift)), shift_right(new_value, u32(value_shift)), value_shift > 0);
    }
}

fn serialize_to_10_bit (number : f32) -> u32 {
    let sign = u32(number < 0.0);
    let number_u32 = frexp(abs(number));
    let exponent = u32(clamp(number_u32.exp + 8, 0, 31));
    let mantissa = u32(round(ldexp(number_u32.fract, 4)));

    return (sign << 9) + (exponent << 4) + mantissa;
}

fn parse_from_10_bit (bits : u32) -> f32 {
    let sign_bit = f32(bits >> 9);
    let exponent = f32((bits >> 4) & 31u) - 8.0;
    let mantissa = f32(bits & 15) / 16.0 + 1.0;
    
    return (1.0 - sign_bit * 2.0) *  pow(2.0, exponent) * mantissa;
}

const pos_chunk_ratio = 8192 / (CHUNK_LENGTH * 16);

fn get_x_pos () -> f32 {
    let x_pos_in_chunk = get_sub_integer_entity(base_entity_integer_sub_divisions.x_position);
    let chunk_x_pos = get_sub_integer_entity(base_entity_integer_sub_divisions.chunk) % world_dimensions.x;
    return f32(chunk_x_pos * CHUNK_LENGTH * 16) + f32(x_pos_in_chunk) / f32(pos_chunk_ratio);
}

fn get_y_pos () -> f32 {
    let y_pos_in_chunk = get_sub_integer_entity(base_entity_integer_sub_divisions.y_position);
    let chunk_y_pos = get_sub_integer_entity(base_entity_integer_sub_divisions.chunk) / world_dimensions.x;
    return f32(chunk_y_pos * CHUNK_LENGTH * 16) + f32(y_pos_in_chunk) / f32(pos_chunk_ratio);
}

fn update_entity_position () {
    let world_dimensions_in_chunks = world_dimensions / 8;

    var serialized_x_position : u32 = u32(round(x_position * f32(pos_chunk_ratio)));
    if (serialized_x_position >= 4096) {
        chunk_x += 1;
        serialized_x_position -= 4096;
    }
    
    set_sub_integer_entity(base_entity_integer_sub_divisions.x_position, serialized_x_position);
    
    var serialized_y_position : u32 = u32(round(y_position * f32(pos_chunk_ratio)));
    if (serialized_y_position >= 4096) {
        chunk_y += 1;
        serialized_y_position -= 4096;
    }
    
    set_sub_integer_entity(base_entity_integer_sub_divisions.y_position, serialized_y_position);

    set_sub_integer_entity(base_entity_integer_sub_divisions.chunk, chunk_x + chunk_y * world_dimensions.x);
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
struct SpriteIndexMapStruct {
    // player_looking_right: u32,
    // player_looking_left: u32,
    // drill: u32,
    // rope: u32,
    // block: u32,
    // sprite insert
    john_looking_right: u32,
    john_looking_left: u32,
    drill: u32,
    rope: u32,
    block: u32,
    monster: u32,
    pipe: u32
    // sprite insert
}
const sprite_index_map = SpriteIndexMapStruct(
    // 0,
    // 1,
    // 2,
    // 3,
    // 4,
    // sprite insert
    0,
    1,
    2,
    3,
    4,
    5,
    6
    // sprite insert
);

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
    for (var offset : u32 = range.x; offset < range.y; offset += 32) {
        let mask_start : u32 = clamp(range.x - offset, 0, 32);
        let mask_end : i32 = 31 - i32(range.y) + i32(offset);
        let bit_mask_start = shift_right(0xFFFFFFFFu, mask_start);
        let bit_mask_end = shift_left(0xFFFFFFFFu, u32(clamp(mask_end, 0, 32)));
        let masked_integer = input_integers[offset / 32] & bit_mask_start & bit_mask_end;

        if (mask_end < 0) {
            sub_integer += shift_left(masked_integer, u32(-mask_end));
        } else {
            sub_integer += shift_right(masked_integer, u32(mask_end));
        }
    }

    return sub_integer;
}

fn get_bit_from_input(index : u32) -> u32 { // Use this to quickly get single digits
    return (shift_right(players_input[index / 32], (31 - index % 32))) & 1u;
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

// CHANGE IT BACK TO 64 1 1
@compute @workgroup_size(1, 1, 1) fn cShader(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    if (global_invocation_id.x >= arrayLength(&entities_indicies)) { return; }

    entity_index = entities_indicies[global_invocation_id.x];
    for (var i : u32 = 0; i < NO_OF_INTEGERS_PER_ENTITY; i++) { entity_integers[i] = entities_buffer_0[entity_index * 7 + i]; }


    entity_type = (entity_integers[0] >> 23) & 511;
    if (entity_type != 0) {
        x_position = get_x_pos();
        y_position = get_y_pos();
        x_velocity = parse_from_10_bit(get_sub_integer_entity(base_entity_integer_sub_divisions.x_velocity));
        y_velocity = parse_from_10_bit(get_sub_integer_entity(base_entity_integer_sub_divisions.y_velocity));
        rotation   = f32(get_sub_integer_entity(base_entity_integer_sub_divisions.rotation)) * 2 * pi / 8192.0;
        get_input();

        // debug_data = 0xFFFFFFFFu >> 31u;

    // else
    if (entity_type == 1) { main_john(); } else
    if (entity_type == 2) { main_block(); } else
    if (entity_type == 3) { main_drill(); } else
    if (entity_type == 4) { main_rope(); }

        do_the_physics();
        
        //  x       y       rotation  sprite
        // 0101010 1010101 010101010 101010101
        let serialized_x_position = u32(floor(x_position)) % 127;
        let serialized_y_position = u32(floor(y_position)) % 127;
        let serialized_rotation = u32(round(rotation * 512.0 / (pi * 2.0))) % 511;
        sprites_target[global_invocation_id.x] = (serialized_x_position << 25) + (serialized_y_position << 18) + (serialized_rotation << 9) + current_sprite;


        set_sub_integer_entity(base_entity_integer_sub_divisions.x_velocity, serialize_to_10_bit(x_velocity));
        set_sub_integer_entity(base_entity_integer_sub_divisions.y_velocity, serialize_to_10_bit(y_velocity));
        for (var i : u32 = 0; i < NO_OF_INTEGERS_PER_ENTITY; i++) { entities_buffer_1[entity_index * 7 + i] = entity_integers[i]; }
    
        // debug_data = get_y_pos();
    }
    
} 

fn do_the_physics() {
    x_position += x_velocity;
    y_position += y_velocity;
    update_entity_position();
}


fn handle_collision(collider: u32) {
// else
    if (entity_type == 1) { handle_collision_john(collider); } else
    if (entity_type == 2) { handle_collision_block(collider); } else
    if (entity_type == 3) { handle_collision_drill(collider); } else
    if (entity_type == 4) { handle_collision_rope(collider); }
}

fn Q_rsqrt(x: f32) -> f32 { // Thank you quake
    let y = bitcast<f32>(0x5f3759df - ( bitcast<u32>(x) >> 1 ));
    return y * (1.5 - y * y * x * 0.5);
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
    mass: u32,
    default_sprite: u32
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
    60, // in kilograms
    sprite_index_map.john_looking_right
);

fn main_john() {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == entity_index) {
        control_john();
    }

    current_sprite = EntityData_john.default_sprite;
}

fn control_john() {
    let w_pressed = get_bit_from_input(base_input_integer_sub_divisions.w[0]);
    let a_pressed = get_bit_from_input(base_input_integer_sub_divisions.a[0]);
    let s_pressed = get_bit_from_input(base_input_integer_sub_divisions.s[0]);
    let d_pressed = get_bit_from_input(base_input_integer_sub_divisions.d[0]);

    let dir_vec = vec2i(
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );

    x_position += f32(dir_vec.x);
    y_position += f32(dir_vec.y);
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
    mass: u32,
    default_sprite: u32
}

const EntityData_block = DataStruct_block(
    4,
    array(
        vec2f(-8, 8),
        vec2f(8, 8),
        vec2f(8, -8),
        vec2f(-8, -8)
    ),
    100,
    sprite_index_map.block
);

fn main_block() {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == entity_index) {
        control_block();
    }

    current_sprite = EntityData_block.default_sprite;
}

fn control_block() {
    let w_pressed = get_bit_from_input(base_input_integer_sub_divisions.w[0]);
    let a_pressed = get_bit_from_input(base_input_integer_sub_divisions.a[0]);
    let s_pressed = get_bit_from_input(base_input_integer_sub_divisions.s[0]);
    let d_pressed = get_bit_from_input(base_input_integer_sub_divisions.d[0]);

    let dir_vec = vec2i(
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );

    x_position += f32(dir_vec.x);
    y_position += f32(dir_vec.y);
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
    nodes: array<vec2f, 10>,
    mass: u32,
    default_sprite: u32
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
    15, // in kilograms
    sprite_index_map.drill
);

fn main_drill() {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == entity_index) {
        control_drill();
    }

    current_sprite = EntityData_drill.default_sprite;
}

fn control_drill() {
    let w_pressed = get_bit_from_input(base_input_integer_sub_divisions.w[0]);
    let a_pressed = get_bit_from_input(base_input_integer_sub_divisions.a[0]);
    let s_pressed = get_bit_from_input(base_input_integer_sub_divisions.s[0]);
    let d_pressed = get_bit_from_input(base_input_integer_sub_divisions.d[0]);

    let dir_vec = vec2i(
        i32(d_pressed) - i32(a_pressed),
        i32(w_pressed) - i32(s_pressed),
    );
    
    x_position += f32(dir_vec.x);
    y_position += f32(dir_vec.y);
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
    mass: u32,
    default_sprite: u32
}

const EntityData_rope = DataStruct_rope(
    4, // for the for loops to know how many times to loop automatically in the physics function
    array(
        vec2f(-0.5, 1.0),
        vec2f(0.5, 1.0),
        vec2f(0.5, -1.0),
        vec2f(-0.5, -1.0),
    ),
    2, // in kilograms
    sprite_index_map.rope
);

fn main_rope() {
    if (get_sub_integer_input(base_input_integer_sub_divisions.entity_id) == entity_index) {
        control_rope();
    }

    current_sprite = EntityData_rope.default_sprite;
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

    x_position += f32(dir_vec.x);
    y_position += f32(dir_vec.y);
}

fn handle_collision_rope(collider : u32) {
    // rope dies
}