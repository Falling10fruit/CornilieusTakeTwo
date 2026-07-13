@group(1) @binding(1) var<storage, read_write> workgroup_histogram : array<array<u32, 16>>; // length 8192 for 2^24 entities

@group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override ENTITY_COUNT_LOG2 : u32 = 24u;
override ITERATION_COUNT : u32 = 32u >> (24 - ENTITY_COUNT_LOG2);

var<workgroup> per_32_sums : array<u32, 256>;
var<private> sum_so_far : u32 = 0;
var<private> digits : vec4u = vec4u(0, 0, 0, 0);

// 16 workgroups for each of the bytes
@compute @workgroup_size(256) fn main(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_invocation_index : u32,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(num_workgroups) no_of_workgroups : vec3u
) {
    for (var i : u32 = 0; i < ITERATION_COUNT; i++) {
        let current_count = workgroup_histogram[local_invocation_index + 256 * i][workgroup_id.x];
        digits[i >> 3] += sum_so_far << ((i & 7u) << 2);
        sum_so_far += current_count;
    }

    per_32_sums[local_invocation_index] = sum_so_far;

    workgroupBarrier();
    for (var stride : u32 = 1; stride < 256; stride <<= 1) {
        var temporary : u32;
        if (local_invocation_index >= stride) {
            temporary = per_32_sums[local_invocation_index - stride];
        } workgroupBarrier();
        
        
        if (local_invocation_index >= stride) {
            per_32_sums[local_invocation_index] += temporary;
        } workgroupBarrier();
    }

    workgroup_histogram[0][workgroup_id.x] = 0;
    for (var i : u32 = 0; i < ITERATION_COUNT; i++) {
        if (local_invocation_index > 0 || i > 0) {
            workgroup_histogram[local_invocation_index + 256 * i + 1][workgroup_id.x] = per_32_sums[local_invocation_index] + ((digits[i >> 3] >> ((i & 7u) << 2)) & 0xFu);
        }
    } workgroupBarrier();
}