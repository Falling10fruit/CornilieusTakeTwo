// 
//    Entity index (creation order)
// 01010101 01010101 01010101 01010101
// type (2^9 = 512)    chunk index 2^16        xPos(2^13)      yPos (16 * 8 pixels divided by 2^13)       rotation 2^13 
//   [ 010101010 ]   [ 1010101010101010 ] [ 1010101 | 010101 ]           [ 0101010101010 ]              [ 1010101010101 ] |
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

const NO_OF_INTEGERS_PER_ENTITY : u32 = 7;
alias EntityIntegers = array<u32, NO_OF_INTEGERS_PER_ENTITY>;

@group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_0 : array<u32>;
alias points_to_entities_buffer_0 = ptr<storage, array<u32>, read_write>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_1 : array<u32>;
alias points_to_entities_buffer_1 = ptr<storage, array<u32>, read_write>;


// First index is player count   controlled entity's index   qwe asd zxc rfv tgb yhn tab shift ctrl alt 0123456789  mouse_left mouse_middle mouse_right mouse rotation = 2^13 = ?? degrees mouse x      mouse y
//                               010101010101010101010101    010 101 010 101 010 101 0   1     0    1   0101010101  0          1            0           10101 01010101                     010101010101 010101010101
// Chat agrees that this should be a storage buffer, calm down yoga - 7 dec 2025
@group(2) @binding(0) var<storage, read> players_input : array<u32>;
@group(2) @binding(1) var<uniform> world_dimensions : vec2u;

var<private> entity_index : u32;
var<private> chunk_x : u32;
var<private> chunk_y : u32;
var<private> x_position : f32;
var<private> y_position : f32;
var<private> rotation : f32;
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

fn get_x_position_in_chunk () -> f32 { return f32(get_sub_integer_entity(base_entity_integer_sub_divisions.x_position))/32.0; }
fn get_y_position_in_chunk () -> f32 { return f32(get_sub_integer_entity(base_entity_integer_sub_divisions.y_position))/32.0; }

fn update_entity_position () -> f32 {
    let world_dimensions_in_chunks = world_dimensions / 8;

    let serialized_x_position : u32 = u32(round(x_position * 32.0));
    if (serialized_x_position >= 4096) {
        chunk_x += 1;
        serialized_x_position -= 4096;
    }
    
    set_sub_integer_entity(base_entity_integer_sub_divisions.x_position, serialized_x_position);
    
    let serialized_y_position : u32 = u32(round(y_position * 32.0));
    if (serialized_y_position >= 4096) {
        chunk_y += 1;
        serialized_y_position -= 4096;
    }
    
    set_sub_integer_entity(base_entity_integer_sub_divisions.y_position, serialized_y_position);

    set_sub_integer_entity(base_entity_integer_sub_divisions.chunk, )
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

fn update_sprite(sprite_index : u32) {

    sprites_target[entity_index] = 
}

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
    let entity_buffer_ptr_0 : points_to_entities_buffer_0 = &entities_buffer_0;
    let entity_buffer_ptr_1 : points_to_entities_buffer_1 = &entities_buffer_1;
    entity_index = global_invocation_id.x;

    if (entity_index >= arrayLength(entity_buffer_ptr_0)) { return; }
    for (var i : u32 = 0; i < NO_OF_INTEGERS_PER_ENTITY; i++) { entity_integers[i] = entities_buffer_0[entity_index * 7 + i]; }

    entity_type = (entity_integers[1] >> 23) & 511;
    x_position = get_x_vel();
    y_position = get_y_vel();
    get_input();


// insert here

    do_the_physics();
} 

fn do_the_physics() {
    // if (entity_type == 1) {
    //     // main_john(index, index_in_buffer);
    // }
}


fn handle_collision(collider: u32) {
// insert here
}