@group(0) @binding(0) var<storage, read_write> current_sprites_buffer : array<u32>;
@group(0) @binding(1) var<storage, read_write> target_sprites_buffer : array<u32>;

fn round_to_u32(num : f32) -> u32 {
    let rounded_f32 = select(floor(num), ceil(num), (fract(num) < 0.5));
    return u32(rounded_f32);
}

@compute @workgroup_size(256, 1, 1) fn cShader( // alter this manually, currently 2^22
    @builtin(global_invocation_id) global_invocation_id : vec3u,
) {
    let index = global_invocation_id.x;

    let current_sprite = current_sprites_buffer[index];
    let target_sprite = target_sprites_buffer[index];

    let current_x_position : f32 = f32((current_sprite >> 25) & 127u);
    let current_y_position : f32 = f32((current_sprite >> 18) & 127u);
    let current_angle : f32 = f32((current_sprite >> 9) & 511u);

    let target_x_position : f32 = f32((target_sprite >> 25) & 127u);
    let target_y_position : f32 = f32((target_sprite >> 18) & 127u);
    let target_angle : f32 = f32((target_sprite >> 9) & 511u);
    
    let new_x_position = round_to_u32(mix(current_x_position, target_x_position, 0.05));
    let new_y_position = round_to_u32(mix(current_y_position, target_y_position, 0.05));
    let new_angle = round_to_u32(mix(current_angle, target_angle, 0.05));

    current_sprites_buffer[index] =
        ((new_x_position % 128) << 25) +
        ((new_y_position % 128) << 18) +
        ((new_angle      % 512) << 9 ) +
        (current_sprite & 511u);
}