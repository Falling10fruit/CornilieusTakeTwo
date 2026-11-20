// most significant bit is if it's uncovered (0 covered 1 uncovered) and the bit next to it is if it's a bomb (0 bomb 1 tile) and then the next bit is if it has a flag
// uncovered | bomb   | flagged | animation stage             | number
//     0         1        0       10101 01010101 01010101 0101   0101
@group(0) @binding(0) var<storage, read_write> tiles:array<u32>;

struct Grid {
    dimensions:vec2u,
    square_len:u32,
    size:vec2u,
    top_left:vec2u
}
@group(0) @binding(1) var<uniform> grid:Grid;

//  mouse x        mouse y     |         left/right mouse button (0 left 1 right) |  mouse down 
// 01010101 0101 0101 01010101 |  010101                   0                               1  
@group(0) @binding(2) var<uniform> mouse:u32;
fn get_mouse_tile_idx() -> u32 {
    let x = mouse >> 20;
    let y = (mouse >> 8) & 0xFFFu;
    return EncodeMorton2(vec2u(x, y));
}

//                                         dead yet (1 yes 0 no)
// 01010101 01010101 01010101 0101010                1
@group(0) @binding(3) var<storage, read_write> game:u32;
@group(1) @binding(0) var<storage, read_write> debug_buffer : u32;

override seed:u32;
// Jarzynski and Olano
fn pcg_hash(input:u32) -> u32 {
    let state = (input + seed) * 747796405u + 2891336453u;
    let word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

// https://fgiesen.wordpress.com/2009/12/13/decoding-morton-codes/ no clue how it works but thx
fn EncodeMorton2(coord:vec2u) -> MortonIDX { return (Part1By1(coord.y) << 1) + Part1By1(coord.x); }
fn Part1By1(x:u32) -> u32 {
  var x = x & 0x0000ffff; // x = ---- ---- ---- ---- fedc ba98 7654 3210
  x = (x ^ (x <<  8)) & 0x00ff00ff; // x = ---- ---- fedc ba98 ---- ---- 7654 3210
  x = (x ^ (x <<  4)) & 0x0f0f0f0f; // x = ---- fedc ---- ba98 ---- 7654 ---- 3210
  x = (x ^ (x <<  2)) & 0x33333333; // x = --fe --dc --ba --98 --76 --54 --32 --10
  x = (x ^ (x <<  1)) & 0x55555555; // x = -f-e -d-c -b-a -9-8 -7-6 -5-4 -3-2 -1-0
  return x;
} alias MortonIDX = u32;

fn index_to_coord(index:u32) -> vec2u { return vec2u(index % grid.dimensions.x, index / grid.dimensions.x); }

const surrounding_tile_offsets:array<vec2i, 8> = array(
    vec2i(-1,  1), vec2i( 0,  1), vec2i( 1,  1),
    vec2i(-1,  0), /*  middle  */ vec2i( 1,  0),
    vec2i(-1, -1), vec2i( 0, -1), vec2i( 1, -1),
);

@compute @workgroup_size(256) fn plant_bombs(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }
    
    let tile_pos = index_to_coord(global_id.x);
    let index = EncodeMorton2(tile_pos);
    let tile_idx = get_mouse_tile_idx();
    
    var is_on_any = index == tile_idx;
    for (var i = 0u; i < 8; i++) {
        is_on_any = is_on_any || EncodeMorton2(vec2u(vec2i(tile_pos) + surrounding_tile_offsets[i])) == tile_idx;
    }

    if (is_on_any) {
        tiles[index] = 1u << 31;
    } else {
        let ran = f32(pcg_hash(index))/f32(0xFFFFFFFFu);
        tiles[index] = select(1u << 31, 3u << 30, ran < 0.2);
    }
}

@compute @workgroup_size(256) fn mark_squares(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }

    let this_tile = tiles[global_id.x];
    if (((this_tile >> 30) & 1u) == 1u) { return; }
    let tile_pos= index_to_coord(global_id.x);
    
    var count = 0u;
    for (var i = 0u; i < 8; i++) {
        count += u32(((tiles[EncodeMorton2(vec2u(vec2i(tile_pos) + surrounding_tile_offsets[i]))] >> 30) & 1u) == 1u);
    }

    tiles[EncodeMorton2(tile_pos)] += count;
}

struct MouseClick { left:bool, right:bool }
fn is_clicked(this_id:u32) -> MouseClick {
    let mouse_down = ((game >> 1) & 1u) == 1u;
    let left_mouse_down = (((game >> 2) & 1u) == 0u);
    return MouseClick(left_mouse_down && mouse_down, !left_mouse_down && mouse_down);
}

@compute @workgroup_size(256) fn tick(
    @builtin(global_invocation_id) global_id:vec3u
) { if (global_id.x >= arrayLength(&tiles)) { return; }

    let mouse_idx = get_mouse_tile_idx();
    let index = EncodeMorton2(index_to_coord(global_id.x));
    var this_tile = tiles[index];
    if (this_tile >> 31 == 0u) {
        if (mouse_idx == index) {
            if ((mouse & 3u) == 3u) {
                tiles[index] ^= (1u << 29);
                return;
            }

            if ((mouse & 3u) == 1u) {
                this_tile ^= ~(1u << 31);
            }
        }
    }

    if (this_tile >> 30 == 3u) {
        game |= 1u;
        return;
    }

    let this_count = this_tile & 0xFFu;
    if (mouse_idx == index) {
        if ((mouse & 1u) == 1u) {
            for (var i = 0u; i < 8; i++) {

            }
        }
    }

}