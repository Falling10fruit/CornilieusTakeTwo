// 
//    Entity index (creation order)
// 01010101 01010101 01010101 01010101
// type (2^9 = 512) chunk index 2^16   xPos(2^13)    yPos (16 * 8 pixels divided by 2^13) rotation 2^13 
//    010101010     1010101010101010 1010101 010101           0101010101010               1010101010101
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101
// 2^10 -> 1023          2^12 -> 4095
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
var<private> entity_index_position : vec3u;
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
    one : vec2u,
    two : vec2u,
    three : vec2u,
    four : vec2u,
    mouse_left : vec2u,
    mouse_middle : vec2u,
    mouse_right : vec2u,
    mouse_rotation : vec2u
}
const base_input_integer_sub_divisions = BaseInputIntegerSubDivisions(
    vec2u(0, 23)
);
var<private> input_integers : InputIntegers;


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

fn get_bit_from_input(index : u32) -> u32 {
    let integer : u32 = 
    return 
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

@compute @workgroup_size(64, 1, 1) fn cShader(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    if (global_invocation_id >= arrayLength(entities_buffer_0)) { return; }

    for (var i = 0; i < NO_OF_INTEGERS_PER_ENTITY; i++) { entity_integers[i] = entities_buffer_0[global_invocation_id.x * 7 + i]; }
    entity_type = (entity_integers[1] >> 23) & 511;

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