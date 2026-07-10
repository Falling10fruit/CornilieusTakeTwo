@group(0) @binding(0) var<storage> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;
struct AtomicCount {
    count: atomic<u32>,
    prefix_sum: u32
}
@group(1) @binding(0) var<storage, read_write> byte_count : array<AtomicCount>;
@group(1) @binding(1) var<storage, read_write> workgroup_histogram : array<array<u32, 16>>; // so a 16 by 8192 for a 2^24 entity

override BIT_SHIFT : u32 = 0; // four passes to get all 4 bits of 2 bytes

var<workgroup> local_buckets : array<atomic<u32>, 16>;

// 8,192 dispatches [chunks] for 2^24 entities
@compute @workgroup_size(256) fn chunk_count( 
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(num_workgroups) no_of_dispatches : vec3u,
    @builtin(local_invocation_index) local_invocation_index : u32
) {
    for (var subthread_offset = 0u; subthread_offset < 8; subthread_offset++) {
        let bucket_index = (entity_buffer_0[global_invocation_id.x + 256 * no_of_dispatches.x * subthread_offset].x >> (7 + BIT_SHIFT)) & 0xFu;
        atomicAdd(&local_buckets[bucket_index], 1u); // ai told me that this heavily contested, albiet local, writing will kill me. uh. TODO fix this
    }

    workgroupBarrier();

    if (local_invocation_index < 16) {
        let local_count = atomicLoad(&local_buckets[local_invocation_index]);
        if (local_count != 0u) { // if local_count is zero then don't spend bandwidth incrementing nothing
            atomicAdd(&byte_count[local_invocation_index].count, local_count);
            workgroup_histogram[workgroup_id.x][local_invocation_index] = local_count;
        }
    }
}