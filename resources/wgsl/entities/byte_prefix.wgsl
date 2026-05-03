//    Entity index grouped by type
// 01010101 01010101 01010101 01010101
// type = 0 means no entity
// type (2^9 = 512)     chunk index 2^16         xPos(2^13)       yPos (16 * 8 pixels divided by 2^13)         rotation 2^13 
//  [ 01010101 0 ]   [ 1010101 01010101 0 ] [ 1010101 | 010101 ]           [ 01 01010101 010 ]              [ 10101 01010101 ] |
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 
// 2^10 -> 1023          2^12 -> 4095
//01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101
struct AtomicCount {
    count: atomic<u32>,
    prefix_sum: u32
}
@group(0) @binding(2) var<storage, read_write> byte_count : array<AtomicCount>;

@compute @workgroup_size(256) fn sort_entities( //
    @builtin(local_invocation_index) local_invocation_index : u32,
) {
    var sum : u32 = 0;
    for (var i : u32 = 0; i < local_invocation_index; i++) {
        sum += atomicLoad(&byte_count[i].count);
    }
    byte_count[local_invocation_index].prefix_sum = sum;
}