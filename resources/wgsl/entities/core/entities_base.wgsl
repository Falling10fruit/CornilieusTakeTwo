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

struct EntityData {
    gjk_bounds_dictionary_pointer: u32,
    gjk_bounds_count: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(0) @binding(0) var<storage, read> entity_type_data : array<EntityData>;
@group(0) @binding(1) var<storage, read> entity_nodes : array<vec2f>;
@group(0) @binding(2) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(3) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(5) var<storage, read_write> entities_buffer_1 : array<vec4u>;
@group(0) @binding(6) var<storage, read_write> entities_buffer_meta : array<vec4u>;


@group(1) @binding(0) var<storage, read_write> debug_buffer : f32; // ##DEBUG_TYPE##
@group(1) @binding(1) var<storage, read>       cosin_lut : array<vec2f>;
@group(1) @binding(2) var<storage, read>       hilbert_curve : array<u32>;
@group(1) @binding(3) var<storage, read>       world_data : array<u32>;

override WORLD_WIDTH_IN_CHUNKS : u32; 
override WORLD_HEIGHT_IN_CHUNKS : u32;
override CHUNK_LENGTH : u32;
override POS_CHUNK_RATIO : f32 = f32(8192 / (CHUNK_LENGTH * 16));

var<private> entity_vector : vec4u;
var<private> other_entity_vector : vec4u;
var<private> entity_index : u32;
var<private> entity_type : u32;
var<private> current_entity_data : EntityData;
var<private> chunk_index : u32;
var<private> chunk_x : u32;
var<private> chunk_y : u32;
var<private> local_position : vec2f;
var<private> global_position : vec2f;
var<private> x_velocity : f32;
var<private> y_velocity : f32;
var<private> rotation : f32; // in the 2^13 format 0 - 8191
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
    let sub_value_0 = new_value >> select(0, range.y - offset_0 - 31, range.y > offset_0 + 31);
    start_integer = insertBits(start_integer, sub_value_0, 31 - end_0, end_0 - start_0 + 1);
    set_entity_integer(start_index, start_integer);

    let end_index = range.y >> 5;
    if (start_index != end_index) {
        var end_integer = index_entity_integer(end_index);

        let offset_1 = end_index << 5;
        let start_1 = clamp(range.x - offset_1, 0, 31);
        let end_1 = range.y - offset_1;
        let sub_value_1 = new_value >> select(0, range.y - offset_1 - 31, range.y > offset_1 + 31);
        end_integer = insertBits(end_integer, sub_value_1, 31 - end_1, end_1 - start_1 + 1);

        set_entity_integer(end_index, end_integer);
    }

}

fn parse_local_position() {
    let x_position_raw = ((entity_vector.x & 0x7Fu) << 6) + (entity_vector.y >> 26);
    let x_position_shift = countLeadingZeros(x_position_raw) + 1;
    let x_position = bitcast<f32>((133 << 23) + (((x_position_raw << x_position_shift) >> x_position_shift) << (x_position_shift - 9)));

    let y_position_raw = ((entity_vector.y >> 13) & 0x1FFFu);
    let y_position_shift = countLeadingZeros(y_position_raw) + 1;
    let y_position = bitcast<f32>((133 << 23) + (((y_position_raw << y_position_shift) >> y_position_shift) << (y_position_shift - 9)));

    local_position = vec2f(x_position, y_position);
}

fn serialize_to_10_bit (number : f32) -> u32 {
    let ieee_754 = bitcast<u32>(number);
    let sign = ieee_754 >> 31;
    let exponent = bitcast<u32>(clamp(bitcast<i32>((ieee_754 >> 23) & 0xFFu) - 119, 0, 31));
    let rounding = (ieee_754 >> 18) & 1u;
    let mantissa = ((ieee_754 >> 19) & 0xFu) + rounding;

    return (sign << 9) + min((exponent << 4) + mantissa, 0x1FF);
}

fn parse_from_10_bit (bits : u32) -> f32 {
    let sign_bit = bits >> 9;
    let exponent = (bits >> 4) & 0x1Fu;
    let mantissa = bits & 0xFu;
    
    return bitcast<f32>((sign_bit << 31) + ((exponent + 119) << 23) + (mantissa << 19));
}

fn update_entity_position () {
    let x_position_13_bit : u32 = u32(round((global_position.x) * POS_CHUNK_RATIO));
    let serialized_x_position : u32 = x_position_13_bit  % 8192;
    chunk_x = x_position_13_bit >> 13;
    
    let y_position_13_bit : u32 = u32(round((global_position.y) * POS_CHUNK_RATIO));
    let serialized_y_position : u32 = y_position_13_bit  % 8192;
    chunk_y = y_position_13_bit >> 13;
    
    set_sub_integer_entity(entity_sub_int_x_position, serialized_x_position);
    set_sub_integer_entity(entity_sub_int_y_position, serialized_y_position);
    set_sub_integer_entity(entity_sub_int_chunk, chunk_x + chunk_y * WORLD_WIDTH_IN_CHUNKS);
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
@group(3) @binding(0) var<storage, read_write> sprites_target : array<vec2u>;
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

@compute @workgroup_size(32) fn cShader(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    entity_index = entities_indicies[global_invocation_id.x];
    entity_vector = entities_buffer_0[entity_index];


    entity_type = (entity_vector.x >> 23) & 511;
    if (entity_type != 0) {
        chunk_index = get_sub_integer_entity(entity_sub_int_chunk);
        current_entity_data = entity_type_data[entity_type];
        current_sprite = current_entity_data.default_sprite;
        chunk_x = chunk_index % WORLD_WIDTH_IN_CHUNKS;
        chunk_y = chunk_index / WORLD_WIDTH_IN_CHUNKS;

        parse_local_position();
        global_position = local_position + vec2f(f32(chunk_x), f32(chunk_y * 16 * CHUNK_LENGTH));
        
        x_velocity = parse_from_10_bit(get_sub_integer_entity(entity_sub_int_x_velocity));
        y_velocity = parse_from_10_bit(get_sub_integer_entity(entity_sub_int_y_velocity));
        rotation   = f32(get_sub_integer_entity(entity_sub_int_rotation)) * 2 * pi / 8192.0;


    // insert here
    
        do_the_physics();

        // if (entity_index == 1) { debug_buffer = x_position; }

        //   33554432                         65536                   127          127          511     
        //  sprite index                     chunk index             x pos        y pos       rotation
        // 01010101 01010101 01010101 0 ] [ 1010101 |  01010101 0 ] [ 1010101 ] [ 0101010 ] [ 101010101 ]
        let serialized_position = vec2u(global_position);
        let chunk_index = (serialized_position.x >> 7) + WORLD_WIDTH_IN_CHUNKS * (serialized_position.y >> 7);
        let serialized_rotation = u32(round(rotation * 512.0 / (pi * 2.0))) % 511;
        let target_sprite_vector = vec2u(
            (current_sprite << 7) + (chunk_index >> 9),
            (chunk_index << 23) + ((serialized_position.x & 127u) << 16) + ((serialized_position.y & 127u) << 9) + serialized_rotation
        );
        sprites_target[global_invocation_id.x] = target_sprite_vector;

        entities_buffer_1[entity_index] = entity_vector;
    }
}

fn handle_collision(collider : u32) {
    // insert here
}

fn do_the_physics() {
    let world_width_in_chunks_cast_shift = countLeadingZeros(WORLD_WIDTH_IN_CHUNKS) + 1;
    let world_height_in_chunks_cast_shift = countLeadingZeros(WORLD_HEIGHT_IN_CHUNKS) + 1;
    let world_dimension_in_chunks_cast_shift = vec2u(world_width_in_chunks_cast_shift, world_height_in_chunks_cast_shift);
    let exponent = vec2u(166, 166) - world_dimension_in_chunks_cast_shift;
    let mantissa = vec2u(WORLD_WIDTH_IN_CHUNKS, WORLD_HEIGHT_IN_CHUNKS) << world_dimension_in_chunks_cast_shift;
    let world_dimensions_in_pixels = bitcast<vec2f>((exponent << vec2u(23, 23)) + (mantissa >> vec2u(9, 9)));

    global_position.x += x_velocity;
    x_velocity *= 0.97;

    x_velocity = select(x_velocity, 0.0, global_position.x < 0.0 || global_position.x > world_dimensions_in_pixels.x);
    global_position.x = clamp(global_position.x, 0, world_dimensions_in_pixels.x);
    
    global_position.y += y_velocity;
    y_velocity -= 0.0981;
    y_velocity *= 0.97;
    
    y_velocity = select(y_velocity, 0.0, global_position.y < 0.0 || global_position.y > world_dimensions_in_pixels.y);
    global_position.y = clamp(global_position.y, 0.0, world_dimensions_in_pixels.y);

    set_sub_integer_entity(entity_sub_int_x_velocity, serialize_to_10_bit(x_velocity));
    set_sub_integer_entity(entity_sub_int_y_velocity, serialize_to_10_bit(y_velocity));
    
    update_entity_position();
}

fn collide_world () { // maybe resolve during collision since we might as while 
    let local_tile_index = (entity_vector.x & 0x7Fu) + ((entity_vector.y >> 19) & 0x7Fu) * CHUNK_LENGTH + chunk_index * 16 * CHUNK_LENGTH;
    let tile_health = (world_data[local_tile_index] >> 25) & 0x1Fu;
    if (tile_health > 0) {
        debug_buffer = 1.0;
    }
}