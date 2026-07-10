@group(0) @binding(0) var<storage> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> digit_prefix : array<array<u32, 16>>; // length 8192 for 2^24 entities
@group(1) @binding(1) var<storage, read_write> workgroup_histogram : array<array<u32, 16>>; // so a 16 by 8192 for a 2^24 entity

override BIT_SHIFT : u32 = 0; // four passes to get all 4 bits of 2 bytes

var<workgroup> local_buckets : array<array<u32, 256>, 16>;

// 8,192 dispatches [chunks] for 2^24 entities
@compute @workgroup_size(256) fn chunk_count( 
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(num_workgroups) no_of_dispatches : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var subthread_offset = 0u; subthread_offset < 8; subthread_offset++) {
        let bucket_index = (entity_buffer_0[global_invocation_id.x + 256 * no_of_dispatches.x * subthread_offset].x >> (7 + BIT_SHIFT)) & 0xFu;
        local_buckets[bucket_index][local_id] += 1;
        
        for (var digit = 0u; digit < 16; digit++) { for (var stride = 1u; stride <= 256; stride <<= 1) {
            var temp: u32;
            if (local_id >= stride) { temp = local_buckets[digit][local_id - stride]; }
            workgroupBarrier();

            if (local_id >= stride) { local_buckets[digit][local_id] += temp; }
            workgroupBarrier();
        }}
       
        if (local_id < 16) { local_buckets[local_id][0] = local_buckets[local_id][255]; }
        workgroupBarrier();
        for (var digit = 0u; digit < 16; digit++) { if (local_id != 0) { local_buckets[digit][local_id] = 0; } }
        workgroupBarrier();
    }

    if (local_id < 16) {
        let local_count = local_buckets[local_id][255];
        if (local_count != 0u) { // if local_count is zero then don't spend bandwidth incrementing nothing
            digit_prefix[workgroup_id.x][local_id] = local_count;
            workgroup_histogram[workgroup_id.x][local_id] = local_count;
        }
    }
}