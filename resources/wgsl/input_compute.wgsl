@group(0) @binding(0) var<uniform> player_count : u32;
@group(0) @binding(1) var<storage, read> inputs_buffer : array<vec2u>;
@group(0) @binding(2) var<storage, read_write> entities_buffer : array<vec4u>;

var<private> input_vector : vec2u;
var<private> entity_vector : vec4u;

const input_entity_id       = vec2u(0 , 23);
const input_q               = vec2u(24, 24);
const input_w               = vec2u(25, 25);
const input_e               = vec2u(26, 26);
const input_a               = vec2u(27, 27);
const input_s               = vec2u(28, 28);
const input_d               = vec2u(29, 29);
const input_z               = vec2u(30, 30);
const input_x               = vec2u(31, 31);
const input_c               = vec2u(32, 32);
const input_r               = vec2u(33, 33);
const input_f               = vec2u(34, 34);
const input_v               = vec2u(35, 35);
const input_t               = vec2u(36, 36);
const input_g               = vec2u(37, 37);
const input_b               = vec2u(38, 38);
const input_y               = vec2u(39, 39);
const input_h               = vec2u(40, 40);
const input_n               = vec2u(41, 41);
const input_tab             = vec2u(42, 42);
const input_shift           = vec2u(43, 43);
const input_ctrl            = vec2u(44, 44);
const input_alt             = vec2u(45, 45);
const input_0               = vec2u(46, 46);
const input_1               = vec2u(47, 47);
const input_2               = vec2u(48, 48);
const input_3               = vec2u(49, 49);
const input_4               = vec2u(50, 50);
const input_5               = vec2u(51, 51);
const input_6               = vec2u(52, 52);
const input_7               = vec2u(53, 53);
const input_8               = vec2u(54, 54);
const input_9               = vec2u(55, 55);
const input_mouse_left      = vec2u(56, 56);
const input_mouse_middle    = vec2u(57, 57);
const input_mouse_right     = vec2u(58, 58);
const input_mouse_rotation  = vec2u(59, 71);
const input_mouse_x         = vec2u(72, 83);
const input_mouse_y         = vec2u(84, 95);

const entity_sub_int_entity_type = vec2u(0, 8);
const entity_sub_int_x_velocity = vec2u(64, 73);
const entity_sub_int_y_velocity = vec2u(74, 83);
const entity_sub_int_rotation_velocity = vec2u(84, 95);

fn index_input_vector(index : u32) -> u32 {
    switch index {
        case 0: { return input_vector.x; }
        case 1: { return input_vector.y; }
        default: { return 0; }
    }
}

fn get_sub_integer_input(range : vec2u) -> u32 {
    let offset_0 = (range.x >> 5) << 5;
    let start_0 = clamp(range.x - offset_0, 0, 31);
    let end_0 = clamp(range.y - offset_0, 0, 31);
    let bits_0 = extractBits(index_input_vector(offset_0 >> 5), 31 - min(end_0, 31), min(end_0, 31) - max(start_0, 0) + 1);
    let offset_1 = (range.y >> 5) << 5;
    let start_1 = clamp(range.x - offset_1, 0, 31);
    let end_1 = clamp(range.y - offset_1, 0, 31);
    let bits_1 = extractBits(index_input_vector(offset_1 >> 5), 31 - min(end_1, 31), min(end_1, 31) - max(start_1, 0) + 1);

    return (bits_0 << (end_1 + offset_1 - end_0 - offset_0)) | bits_1;
}

// Use this to quickly get single digits
fn get_bit_from_input(index : u32) -> u32 { return (index_input_vector(index/4) >> (3 - index%4)) & 1u; }


fn index_entity_integer(index : u32) -> u32 {
    switch index {
        case 0: { return entity_vector.x; }
        case 1: { return entity_vector.y; }
        case 2: { return entity_vector.z; }
        case 3: { return entity_vector.w; }
        default: { return 0; }
    }
}

fn set_entity_integer(index : u32, new_int : u32) {
    switch index {
        case 0: { entity_vector.x = new_int; }
        case 1: { entity_vector.y = new_int; }
        case 2: { entity_vector.z = new_int; }
        case 3: { entity_vector.w = new_int; }
        default: { }
    }
}

fn get_sub_integer_entity(range : vec2u) -> u32 {
    let offset_0 = (range.x >> 5) << 5;
    let start_0 = clamp(range.x - offset_0, 0, 31);
    let end_0 = clamp(range.y - offset_0, 0, 31);
    let bits_0 = extractBits(index_entity_integer(offset_0 >> 5), 31 - min(end_0, 31), min(end_0, 31) - max(start_0, 0) + 1);
    let offset_1 = (range.y >> 5) << 5;
    let start_1 = clamp(range.x - offset_1, 0, 31);
    let end_1 = clamp(range.y - offset_1, 0, 31);
    let bits_1 = extractBits(index_entity_integer(offset_1 >> 5), 31 - min(end_1, 31), min(end_1, 31) - max(start_1, 0) + 1);

    return (bits_0 << (offset_1 - offset_0 + end_1 - end_0)) | bits_1;
}

fn set_sub_integer_entity(range : vec2u, new_value : u32) {
    let start_index = range.x >> 5; 
    var start_integer = index_entity_integer(start_index);

    let offset_0 = start_index << 5;
    let start_0 = range.x - offset_0;
    let end_0 = clamp(range.y - offset_0, 0, 31);
    let sub_value_0 = new_value >> select(0, range.y - offset_0 - 3, range.y > offset_0 + 3);
    start_integer = insertBits(start_integer, sub_value_0, 31 - end_0, end_0 - start_0 + 1);
    set_entity_integer(start_index, start_integer);

    let end_index = range.y >> 5;
    if (start_index != end_index) {
        var end_integer = index_entity_integer(end_index);

        let offset_1 = end_index << 5;
        let start_1 = clamp(range.x - offset_1, 0, 31);
        let end_1 = range.y - offset_1;
        let sub_value_1 = new_value >> select(0, range.y - offset_1 - 3, range.y > offset_1 + 3);
        end_integer = insertBits(end_integer, sub_value_1, 31 - end_1, end_1 - start_1 + 1);

        set_entity_integer(end_index, end_integer);
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

@compute @workgroup_size(1, 1, 1) fn cShader_input(
    @builtin(global_invocation_id) global_invocation_id : vec3u
) {
    if (global_invocation_id.x >= player_count) { return; }
    input_vector = inputs_buffer[global_invocation_id.x];
    let entity_index = input_vector.x >> 9;
    entity_vector = entities_buffer[entity_index];

    let w_pressed = get_bit_from_input(input_w.x);
    let s_pressed = get_bit_from_input(input_s.x);
    let resultant_y_velocity = w_pressed - s_pressed;

    if (resultant_y_velocity != 0u) {
        set_sub_integer_entity(entity_sub_int_y_velocity, serialize_to_10_bit(parse_from_10_bit(get_sub_integer_entity(entity_sub_int_y_velocity)) + f32(resultant_y_velocity)));
    }
    
    let d_pressed = get_bit_from_input(input_w.x);
    let a_pressed = get_bit_from_input(input_s.x);
    let resultant_x_velocity = d_pressed - a_pressed;

    if (resultant_x_velocity != 0u) {
        set_sub_integer_entity(entity_sub_int_y_velocity, serialize_to_10_bit(parse_from_10_bit(get_sub_integer_entity(entity_sub_int_y_velocity)) + f32(resultant_x_velocity)));
    }

    entities_buffer[entity_index] = entity_vector;
}