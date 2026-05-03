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
    prefix_sum: atomic<u32>
}
@group(0) @binding(0) var<storage, read_write> byte_count : array<AtomicCount>;
@group(0) @binding(1) var<storage> entity_buffer : array<vec4u>;

override BYTE_SHIFT : u32;
var<workgroup> local_buckets : array<atomic<u32>, 256>;

@compute @workgroup_size(256) fn sort_entities( //
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_invocation_index : u32
) {
    atomicStore(&local_buckets[local_invocation_index], 0u);

    workgroupBarrier();

    let bucket_index = (entity_buffer[global_invocation_id.x].x >> (7 + BYTE_SHIFT)) & 0xFFu;
    atomicAdd(&local_buckets[bucket_index], 1u);

    workgroupBarrier();

    let addition = atomicLoad(&local_buckets[local_invocation_index]);
    if (addition != 0u) {
        atomicAdd(&byte_count[local_invocation_index].count, addition);
    }  
}