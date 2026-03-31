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

const entity_sub_int_entity_type = vec2u(0, 8);
const entity_sub_int_chunk = vec2u(9, 24);
const entity_sub_int_x_position = vec2u(25, 37);
const entity_sub_int_y_position = vec2u(38, 50);
const entity_sub_int_rotation = vec2u(51, 63);
const entity_sub_int_x_velocity = vec2u(64, 73);
const entity_sub_int_y_velocity = vec2u(74, 83);
const entity_sub_int_rotation_velocity = vec2u(84, 95);

// chunk indicies descriptor
// index of access is index of chunk, the first 26 bits is the 
//                                  2^6 = 64
// 01010101 01010101 01010101 01 010101

@group(0) @binding(0) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(1) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> entities_buffer_0 : array<vec4u>;
alias points_to_entities_buffer_0 = ptr<storage, array<u32>, read_write>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_1 : array<vec4u>;
alias points_to_entities_buffer_1 = ptr<storage, array<u32>, read_write>;


// First index is player count   controlled entity's index   qwe asd zxc rfv tgb yhn tab shift ctrl alt 0123456789  mouse_left mouse_middle mouse_right mouse rotation = 2^13 = ?? degrees mouse x      mouse y
//                               010101010101010101010101    010 101 010 101 010 101 0   1     0    1   0101010101  0          1            0           10101 01010101                     010101010101 010101010101
// Chat agrees that this should be a storage buffer, calm down yoga - 7 dec 2025
@group(2) @binding(0) var<storage, read_write> debug_data : u32;
@group(2) @binding(1) var<uniform>             world_dimensions : vec2u;
@group(2) @binding(2) var<storage, read>       world_data : array<u32>;

const CHUNK_LENGTH : u32 = 8; // This is so that it can fit in the sprites
var<private> entity_vector : vec4u;
var<private> other_entity_vector : vec4u;
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

const pos_chunk_ratio = 8192 / (CHUNK_LENGTH * 16);

fn get_x_pos () -> f32 {
    let x_pos_in_chunk = get_sub_integer_entity(entity_sub_int_x_position);
    let chunk_x_pos = get_sub_integer_entity(entity_sub_int_chunk) % world_dimensions.x;
    return f32(chunk_x_pos * CHUNK_LENGTH * 16) + f32(x_pos_in_chunk) / f32(pos_chunk_ratio);
}

fn get_y_pos () -> f32 {
    let y_pos_in_chunk = get_sub_integer_entity(entity_sub_int_y_position);
    let chunk_y_pos = get_sub_integer_entity(entity_sub_int_chunk) / world_dimensions.x;
    return f32(chunk_y_pos * CHUNK_LENGTH * 16) + f32(y_pos_in_chunk) / f32(pos_chunk_ratio);
}

fn update_entity_position () {
    let world_dimensions_in_chunks = world_dimensions / 8;

    var serialized_x_position : u32 = u32(round(x_position * f32(pos_chunk_ratio)));
    if (serialized_x_position >= 4096) {
        chunk_x += 1;
        serialized_x_position -= 4096;
    }
    
    set_sub_integer_entity(entity_sub_int_x_position, serialized_x_position);
    
    var serialized_y_position : u32 = u32(round(y_position * f32(pos_chunk_ratio)));
    if (serialized_y_position >= 4096) {
        chunk_y += 1;
        serialized_y_position -= 4096;
    }
    
    set_sub_integer_entity(entity_sub_int_y_position, serialized_y_position);

    set_sub_integer_entity(entity_sub_int_chunk, chunk_x + chunk_y * world_dimensions.x);
}

// 0 10 101010101
fn get_rotation_vel () -> f32 {
    let raw_int = get_sub_integer_entity(entity_sub_int_rotation_velocity);

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

// CHANGE IT BACK TO 64 1 1
@compute @workgroup_size(1, 1, 1) fn cShader(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    if (global_invocation_id.x >= arrayLength(&entities_indicies)) { return; }

    entity_index = entities_indicies[global_invocation_id.x];
    entity_vector = entities_buffer_0[entity_index];

    entity_type = (entity_vector.x >> 23) & 511;
    if (entity_type != 0) {
        x_position = get_x_pos();
        y_position = get_y_pos();
        x_velocity = parse_from_10_bit(get_sub_integer_entity(entity_sub_int_x_velocity));
        y_velocity = parse_from_10_bit(get_sub_integer_entity(entity_sub_int_y_velocity));
        rotation   = f32(get_sub_integer_entity(entity_sub_int_rotation)) * 2 * pi / 8192.0;
        get_input();

    // insert here
    
        // debug_data = get_sub_integer_entity(entity_sub_int_x_position);

        do_the_physics();
        
        //  x       y       rotation  sprite
        // 0101010 1010101 010101010 101010101
        let serialized_x_position = u32(floor(x_position)) % 127;
        let serialized_y_position = u32(floor(y_position)) % 127;
        let serialized_rotation = u32(round(rotation * 512.0 / (pi * 2.0))) % 511;
        sprites_target[global_invocation_id.x] = (serialized_x_position << 25) + (serialized_y_position << 18) + (serialized_rotation << 9) + current_sprite;

        entities_buffer_1[entity_index] = entity_vector;
    }
} 

fn do_the_physics() {
    x_position += x_velocity;
    y_position += y_velocity;
    
    set_sub_integer_entity(entity_sub_int_x_velocity, serialize_to_10_bit(x_velocity));
    set_sub_integer_entity(entity_sub_int_y_velocity, serialize_to_10_bit(y_velocity));
    update_entity_position();
}

fn handle_collision(collider: u32) {
// insert here
}