//    Entity index grouped by type
// 01010101 01010101 01010101 01010101
// type = 0 means no entity
// type (2^9 = 512)     chunk index 2^16         xPos(2^13)       yPos (16 * 8 pixels divided by 2^13)         rotation 2^13 
//  [ 01010101 0 ]   [ 1010101 01010101 0 ] [ 1010101 | 010101 ]           [ 01 01010101 010 ]              [ 10101 01010101 ] |
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 
// 2^10 -> 1023          2^12 -> 4095
//01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101 01010101

@group(0) @binding(0) var<storage> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage> entity_buffer_1 : array<vec4u>;
struct AtomicCount {
    count: atomic<u32>,
    prefix_sum: atomic<u32>
}
@group(1) @binding(0) var<storage, read_write> byte_count : array<AtomicCount>;
@group(1) @binding(1) var<storage, read_write> workgroup_histogram : array<array<u32, 16>>; // 256 buckets of each workgroup. for 2 ^ 24 entities this array is 8192 elements something long

override BYTE_SHIFT : u32;
var<workgroup> local_rank : array<array<u32, 16>, 256>;
var<workgroup> previous_prefix_0 : vec4u; // maximum prefix sum of one workgroup is 2048 - 256, so we can fit 16 sums in 8 integers
var<workgroup> previous_prefix_1 : vec4u;

@compute @workgroup_size(256) fn sort_entities( // 8192 dispatches for 16,770,000 something entities
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_invocation_index : u32,
    @builtin(num_workgroups) no_of_workgroups : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
) {
    for (var i : u32; i < 8; i++) {
        if (local_invocation_index < 8) {
            local_rank[0][local_invocation_index] = (previous_prefix_0[(local_invocation_index >> 1) & 3u] >> (8 * (local_invocation_index & 1u)));
        } else if (local_invocation_index < 16) {
            local_rank[0][local_invocation_index] = (previous_prefix_1[(local_invocation_index >> 1) & 3u] >> (8 * (local_invocation_index & 1u)));
        }
        workgroupBarrier();

        if (local_invocation_index != 0) {
            for (var digit : u32 = 0; digit < 8; digit++) {
                local_rank[local_invocation_index][digit] = 0;    
            }

            for (var digit : u32 = 8; digit < 16; digit++) {
                local_rank[local_invocation_index][digit] = 0;    
            }
        }
        workgroupBarrier();

        let entity_data = entity_buffer_0[global_invocation_id.x + i * no_of_workgroups.x * 256];
        let chunk_byte = (entity_data.x >> (7 + BYTE_SHIFT)) & 0xFu;
        local_rank[local_invocation_index][chunk_byte] += 1;
        workgroupBarrier();

        for (var digit : u32 = 0; digit < 16; digit++) {
            for (var stride : u32 = 1; stride < 256; stride <<= 1) {
                var temporary : u32;
                if (stride <= local_invocation_index) { temporary = local_rank[local_invocation_index - stride][digit]; }
                workgroupBarrier();

                if (stride <= local_invocation_index) { local_rank[local_invocation_index][digit] += temporary; }
                workgroupBarrier();
            }
        }

        let chunk_offset = byte_count[chunk_byte].prefix_sum;
        let local_offset = local_rank[local_invocation_index][chunk_byte];
        entity_buffer_1[chunk_offset + local_offset] = entity_data;
        workgroupBarrier();
    }

    
}