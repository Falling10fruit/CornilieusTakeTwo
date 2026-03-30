@group(0) @binding(0) var<uniform> player_count : u32;
@group(0) @binding(1) var<storage, read> inputs_buffer : array<vec2u>;
@group(1) @binding(2) var<storage, read_write> entities_buffer : array<vec4u>;

var<private> input_vec : vec2u;

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

fn get_sub_integer_input(range : vec2u) -> u32 {
    let offset_0 = (range.x >> 5) << 5;
    let start_0 = clamp(range.x - offset_0, 0, 31);
    let end_0 = clamp(range.y - offset_0, 0, 31);
    let bits_0 = extractBits(input_integers[offset_0 >> 5], 31 - min(end_0, 31), min(end_0, 31) - max(start_0, 0) + 1);
    let offset_1 = (range.y >> 5) << 5;
    let start_1 = clamp(range.x - offset_1, 0, 31);
    let end_1 = clamp(range.y - offset_1, 0, 31);
    let bits_1 = extractBits(input_integers[offset_1 >> 5], 31 - min(end_1, 31), min(end_1, 31) - max(start_1, 0) + 1);

    return (bits_0 << (end_1 + offset_1 - end_0 - offset_0)) | bits_1;
}

// Use this to quickly get single digits
fn get_bit_from_input(index : u32) -> u32 { return (input_integers[index/4] >> (3 - index%4)) & 1u; }

@compute @workgroup_size(1, 1, 1) fn cShader(
    @builtin(global_invocation_id) global_invocation_id : vec3u
) {
    if (global_invocation_id.x >= player_count) { return; }
    input_vec = inputs_buffer[global_invocation_id.x];
    let entity_index = 
}