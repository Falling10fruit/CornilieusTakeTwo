@group(0) @binding(0) var<storage, read_write> hilbert_curve : array<u32>;

override WORLD_WIDTH_IN_CHUNKS : u32;
override WORLD_HEIGHT_IN_CHUNKS : u32;

override curve_order = u32(floor(log2(f32(min(WORLD_WIDTH_IN_CHUNKS, WORLD_HEIGHT_IN_CHUNKS)))));

const points : array<vec2u, 4> = array(
    vec2u(0, 0),
    vec2u(0, 1),
    vec2u(1, 1),
    vec2u(1, 0)
);

    // Hilbert Curve implementation
    // Adapted from Daniel Shiffman / The Coding Train
    // Original tutorial: https://youtu.be/dSK-MW-zuAc
    // License: GNU Lesser General Public License (LGPL v2.1)
fn hilbert(i : u32) -> u32 {
    let index = i & 3;
    var v = points[index];

    for (var j : u32 = 1; j < curve_order; j += 1) {
        let index = (i >> (j * 2)) & 3;
        let len = 1u << j;
    
        let will_invert = index == 3u;
        let temp = vec2u(
            select(v.x, len - 1 - v.x, will_invert),
            select(v.y, len - 1 - v.y, will_invert),
        );

        let will_swap = (index >> 1) == (index & 1u);
        v = select(temp, temp.yx, will_swap);

        let increment = vec2u(
            len * u32(index > 1u),
            len * u32(index == 2u || index == 1u)
        );

        v += increment;
    }

    return v.x + v.y * WORLD_WIDTH_IN_CHUNKS;
}
            
@compute @workgroup_size(256) fn generate_hilbert(
    @builtin(global_invocation_id) index : vec3u
) {
    hilbert_curve[index.x >> 1] = hilbert(index.x) + (hilbert(index.x + 1));
}