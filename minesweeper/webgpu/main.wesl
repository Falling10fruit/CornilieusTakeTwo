// most significant bit is if it's uncovered (0 covered 1 uncovered) and the bit next to it is if it's a bomb (0 bomb 1 tile) and then the next bit is if it has a flag
// uncovered | bomb   | flagged | animation stage                | number
//     0         1        0       10101 01010101 01010101 010101   0101
@group(0) @binding(0) var<storage, read_write> tiles:array<u32>;

struct Grid {
    dimensions:vec2u,
    square_len:u32,
    size:vec2u,
    top_left:vec2u
}
@group(0) @binding(1) var<uniform> grid:Grid;
@group(0) @binding(2) var<uniform> mouse_pos:vec2u;

//                                     left/right mouse button (0 left 1 right) |  mouse down  |  dead yet (1 yes 0 no)
// 01010101 01010101 01010101 01010                   1                               0                1
@group(0) @binding(3) var<storage, read_write> game:u32;
@group(1) @binding(0) var<storage, read_write> debug_buffer : u32;

override seed:u32;
// Jarzynski and Olano
fn pcg_hash(input:u32) -> u32 {
    let state = (input + seed) * 747796405u + 2891336453u;
    let word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

fn coord_to_index(coord:vec2u) -> u32 { return coord.x + coord.y * grid.dimensions.x; }
fn index_to_coord(index:u32) -> vec2u { return vec2u(index % grid.dimensions.x, index / grid.dimensions.x); }

fn get_tile_idx_on_mouse() -> u32 {
    let relative_mouse_pos = mouse_pos - grid.top_left;
    let tile_pos = relative_mouse_pos/grid.square_len;
    return tile_pos.x + tile_pos.y * grid.dimensions.x;
}

const surrounding_tile_offsets:array<vec2i, 9> = array(
    vec2i( 0,  0),
    vec2i( 0,  1),
    vec2i( 1,  0),
    vec2i( 0, -1),
    vec2i(-1,  0),
    vec2i( 1,  1),
    vec2i( 1, -1),
    vec2i(-1, -1),
    vec2i(-1,  1)
);

@compute @workgroup_size(256) fn plant_bombs(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }
    
    let tile_pos = vec2u(global_id.x % grid.dimensions.x, global_id.x / grid.dimensions.y);
    let tile_idx = get_tile_idx_on_mouse();
    
    var is_on_any = false;
    for (var i = 0u; i < 9; i++) {
        is_on_any = is_on_any || coord_to_index(vec2u(vec2i(tile_pos) + surrounding_tile_offsets[i])) == tile_idx;
    }

    if (is_on_any) {
        tiles[global_id.x] = 1u << 31;
    } else {
        let ran = f32(pcg_hash(global_id.x))/f32(0xFFFFFFFFu);
        tiles[global_id.x] = select(1u << 31, 3u << 30, ran < 0.2);
    }
}

@compute @workgroup_size(256) fn mark_squares(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }

    let this_tile = tiles[global_id.x];
    if (this_tile >> 30 == 3) { return; }
    let tile_pos= index_to_coord(global_id.x);
    
    var count = 0u;
    for (var i = 0u; i < 9; i++) {
        count += u32(((tiles[coord_to_index(vec2u(vec2i(tile_pos) + surrounding_tile_offsets[i]))] >> 30) & 1u) == 1u);
    }

    tiles[global_id.x] += count;
}

struct MouseClick { left:bool, right:bool }
fn is_clicked(this_id:u32) -> MouseClick {
    let mouse_inbound =
        all(mouse_pos > grid.top_left) &&
        all(mouse_pos < (grid.top_left + grid.size));
    let mouse_idx = get_tile_idx_on_mouse();
    
    if (mouse_idx != this_id) { return MouseClick(false, false); }

    let mouse_down = ((game >> 1) & 1u) == 1u;
    let left_mouse_down = (((game >> 2) & 1u) == 0u) && mouse_down;
    return MouseClick(left_mouse_down, !left_mouse_down);
}

@compute @workgroup_size(256) fn tick(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }

    let this_tile = tiles[global_id.x];
    if (this_tile >> 31 == 0u) {
        let click_event = is_clicked(global_id.x);
        
    } // if covered
    if (this_tile >> 30 == 3u) {
        game |= 1u;
        return;
    }

}