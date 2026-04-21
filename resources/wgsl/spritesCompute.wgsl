@group(0) @binding(0) var<storage, read_write> debug_buffer : u32;
@group(0) @binding(1) var<storage, read_write> current_sprites_buffer : array<vec2u>;
@group(0) @binding(2) var<storage, read_write> target_sprites_buffer : array<vec2u>;
@group(0) @binding(3) var<uniform> world_dimensions : vec2u;

//   33554432                         65536                    127          127          511     
//  sprite index                     chunk index              x pos        y pos       rotation
// 01010101 01010101 01010101 0 ] [ 1010101 |  01010101 0 ] [ 1010101 ] [ 0101010 ] [ 1 01010101 ]

@compute @workgroup_size(256, 1, 1) fn cShader_sprites( // alter this manually, currently 2^22. we all love hardcoded values, and no I don't know what 2^22 means
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    let index = global_invocation_id.x;

    let current_sprite = current_sprites_buffer[index];
    let target_sprite = target_sprites_buffer[index];

    let current_chunk_index : u32 = ((current_sprite.x &0x7F) << 9) + (current_sprite.y >> 23);
    let current_x_position : f32 = f32(((current_sprite.y >> 16) & 127u) + 128 * (current_chunk_index % world_dimensions.x));
    let current_y_position : f32 = f32(((current_sprite.y >> 9) & 127u) + 128 * (current_chunk_index / world_dimensions.x));
    let current_angle : f32 = f32(current_sprite.y & 511u);

    let target_chunk_index : u32 = ((target_sprite.x &0x7F) << 9) + (target_sprite.y >> 23);
    let target_x_position : f32 = f32(((target_sprite.y >> 16) & 127u) + 128 * (target_chunk_index % world_dimensions.x));
    let target_y_position : f32 = f32(((target_sprite.y >> 9) & 127u) + 128 * (target_chunk_index / world_dimensions.x));
    let target_angle : f32 = f32(target_sprite.y & 511u);
    
    let new_x_position = u32(round(mix(current_x_position, target_x_position, 1.0)));
    let new_y_position = u32(round(mix(current_y_position, target_y_position, 1.0)));
    let new_chunk_index = (new_x_position >> 7) + world_dimensions.x * (new_y_position >> 7);
    let new_angle = u32(round(mix(current_angle, target_angle, 1.0)));

    current_sprites_buffer[index] = vec2u(
        (target_sprite.x & 0xFFFFFF80u) + (new_chunk_index >> 9),
        (new_chunk_index << 23) + ((new_x_position & 127u) << 16) + ((new_y_position & 127u) << 9) + (new_angle)
    );
}