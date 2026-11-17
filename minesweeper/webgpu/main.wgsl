@group(0) @binding(0) var<storage, read_write> tiles:array<u32>;
@group(1) @binding(1) var<uniform> mouse_pos:vec2u;

// idk random numbers
override tiles_dimensions = vec2u(28, 32); 
override viewport = vec2u(1280, 840);

override viewport_div_tiles = (viewport - vec2u(100, 100))/tiles_dimensions;
override square_len:u32 = min(viewport_div_tiles.x, viewport_div_tiles.y);
override grid_dimensions = square_len * tiles_dimensions;
override grid_top_left = viewport/2 - grid_dimensions/2;

override seed:u32;
// Jarzynski and Olano
fn pcg_hash(input:u32) -> u32 {
    let state = (input + seed) * 747796405u + 2891336453u;
    let word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

fn coord_to_index(coord:vec2u) -> u32 { return coord.x + coord.y * tiles_dimensions.x; }

@compute @workgroup_size(256) fn plant_bombs(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }
    let relative_mouse_pos = mouse_pos - grid_top_left;
    let tile_pos_on_mouse = relative_mouse_pos/square_len;

    let on_mouse = coord_to_index(tile_pos_on_mouse) == global_id.x;
    let top_mouse          = coord_to_index(tile_pos_on_mouse + vec2u( 0,  1)) == global_id.x;
    let right_mouse        = coord_to_index(tile_pos_on_mouse + vec2u( 1,  0)) == global_id.x;
    let bottom_mouse       = coord_to_index(tile_pos_on_mouse + vec2u( 0, -1)) == global_id.x;
    let left_mouse         = coord_to_index(tile_pos_on_mouse + vec2u(-1,  0)) == global_id.x;
    let top_right_mouse    = coord_to_index(tile_pos_on_mouse + vec2u( 1,  1)) == global_id.x;
    let bottom_right_mouse = coord_to_index(tile_pos_on_mouse + vec2u( 1, -1)) == global_id.x;
    let bottom_left_mouse  = coord_to_index(tile_pos_on_mouse + vec2u(-1, -1)) == global_id.x;
    let top_left_mouse     = coord_to_index(tile_pos_on_mouse + vec2u(-1,  1)) == global_id.x;
    let is_on_any = 
        on_mouse ||
        top_mouse ||
        right_mouse ||
        bottom_mouse ||
        left_mouse ||
        top_right_mouse ||
        bottom_right_mouse ||
        bottom_left_mouse ||
        top_left_mouse;

    if (is_on_any) {
        tiles[global_id.x] = 0u;
    } else {
        let ran = f32(pcg_hash(global_id.x))/f32(0xFFFFFFFFu);
        tiles[global_id.x] = select(0u, 0xFFFFFFFFu, ran < 0.2);
    }
}

@compute @workgroup_size(256) fn mark_squares(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }

    let this_tile = tiles[global_id.x];
    if (this_tile == 0xFFFFFFFFu) { return; }
    
    let top_tile_is_bomb          = tiles[coord_to_index(global_id.x + vec2u( 0,  1))] == 0xFFFFFFFFu;
    let right_tile_is_bomb        = tiles[coord_to_index(global_id.x + vec2u( 1,  0))] == 0xFFFFFFFFu;
    let bottom_tile_is_bomb       = tiles[coord_to_index(global_id.x + vec2u( 0, -1))] == 0xFFFFFFFFu;
    let left_tile_is_bomb         = tiles[coord_to_index(global_id.x + vec2u(-1,  0))] == 0xFFFFFFFFu;
    let top_right_tile_is_bomb    = tiles[coord_to_index(global_id.x + vec2u( 1,  1))] == 0xFFFFFFFFu;
    let bottom_right_tile_is_bomb = tiles[coord_to_index(global_id.x + vec2u( 1, -1))] == 0xFFFFFFFFu;
    let bottom_left_tile_is_bomb  = tiles[coord_to_index(global_id.x + vec2u(-1, -1))] == 0xFFFFFFFFu;
    let top_left_tile_is_bomb     = tiles[coord_to_index(global_id.x + vec2u(-1,  1))] == 0xFFFFFFFFu;
    let total_bombs =
            u32(top_tile_is_bomb) +
            u32(right_tile_is_bomb) +
            u32(bottom_tile_is_bomb) +
            u32(left_tile_is_bomb) +
            u32(top_right_tile_is_bomb) +
            u32(bottom_right_tile_is_bomb) +
            u32(bottom_left_tile_is_bomb) +
            u32(top_left_tile_is_bomb);

    tiles[global_id.x] = total_bombs;
}