@group(0) @binding(0) var<storage, read_write> current_sprites_buffer : array<vec2u>;
@group(0) @binding(1) var<storage, read_write> target_sprites_buffer : array<vec2u>;

@group(1) @binding(0) var<storage, read_write> debug_buffer : u32;

override WORLD_WIDTH_IN_CHUNKS : u32;
override WORLD_HEIGHT_IN_CHUNKS : u32;
override CHUNK_LENGTH : i32;
override CHUNK_LENGTH_PIXELS : i32 = CHUNK_LENGTH * 16;

//     524288 (2^19)                      2^24                  31        2^5         2^12     
//     sprite index                   chunk index              x pos     y pos      rotation
// 01010101 01010101 010] [ 10101 01010101 |  01010101 010 ] [ 10101 ] [ 01010 ] [ 10101010101 ]

struct SpriteData {
    chunk_position: vec2i,
    local_position: vec2i,
    angle: u32
}

fn extract_sprite_data(sprite_vector: vec2u) -> SpriteData {
    let chunk_index = ((sprite_vector.x & 0x1FFFu) << 11) + (sprite_vector.y >> 21);

    return SpriteData(
        vec2i(
            bitcast<i32>(chunk_index % WORLD_WIDTH_IN_CHUNKS),
            bitcast<i32>(chunk_index / WORLD_WIDTH_IN_CHUNKS) 
        ),
        vec2i(
            bitcast<i32>((sprite_vector.x >> 15) & 0x3Fu),
            bitcast<i32>((sprite_vector.x >> 9 ) & 0x3Fu),
        ),
        sprite_vector.y & 0x1FFu
    );
}

@compute @workgroup_size(256, 1, 1) fn cShader_sprites( // alter this manually, currently 2^22. we all love hardcoded values, and no I don't know what 2^22 means
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    let index = global_invocation_id.x;

    let current_sprite = extract_sprite_data(current_sprites_buffer[index]);
    let target_sprite_vector = target_sprites_buffer[index];
    let target_sprite = extract_sprite_data(target_sprite_vector);

    let chunk_position_delta = target_sprite.chunk_position - current_sprite.chunk_position;
    let local_position_delta = target_sprite.local_position - current_sprite.local_position;
    let global_position_delta = local_position_delta + (chunk_position_delta * CHUNK_LENGTH_PIXELS);
    let new_position = target_sprite.local_position + global_position_delta / 2 + 1;
    let new_chunk_position = bitcast<vec2u>(target_sprite.chunk_position + new_position / CHUNK_LENGTH_PIXELS);
    let new_chunk_index = new_chunk_position.x + new_chunk_position.y * WORLD_WIDTH_IN_CHUNKS;
    let new_local_position = bitcast<vec2u>((new_position + CHUNK_LENGTH_PIXELS) % CHUNK_LENGTH_PIXELS);

    let angle_delta_clockwise = target_sprite.angle - current_sprite.angle;
    let angle_delta_size = angle_delta_clockwise >> 8;
    let angle_delta_smallest = angle_delta_clockwise ^ (0xFFFFFFFFu * angle_delta_size);
    let new_angle = (current_sprite.angle + (angle_delta_smallest >> 1)) & 0x1FFu;

    // -8421  5    7     -8    -6   -2
    //  0101 0101 0111  1000  1010 1110
    //  8421  5    7      8    10   14

    current_sprites_buffer[index] = vec2u(
        (target_sprite_vector.x & 0xFFFFE000u) +
        (new_chunk_index >> 11), (new_chunk_index << 21) +
        (new_local_position.x << 15) + (new_local_position.y << 9) + new_angle
    );
}