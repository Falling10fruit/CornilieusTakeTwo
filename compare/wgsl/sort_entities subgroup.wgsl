enable subgroups;
// type (2^11 = 2048)           chunk index 2^24         xPos(2^8)    yPos (2 * 16 pixels divided by 2^8)     rotation 2^13 
//  [ 01010101 010 ][ 10101 01010101 01010101 | 010 ][ 10101 010 ]             [ 10101 010 ]             [ 10101 01010101 ] |

@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> workgroup_histogram : array<array<u32, 256>>; // length 65536 for 2^24 entities (2^24)/256 = 65536 (64 MiB)
@group(1) @binding(1) var<storage, read_write> global_histogram : array<array<u32, 256>>; // length 256
// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override BYTE_SHIFT : u32 = 0; // 0 -> 2
override ENTITY_COUNT_LOG2 : u32 = 24u; // only down to 20

override MINIMUM_SUBGROUP_SIZE : u32 = 32u; // or 16
override MAXIMUM_SUBGROUP_COUNT : u32 = 256u / MINIMUM_SUBGROUP_SIZE;
var<workgroup> shared_prefix : array<array<vec4u, 16>, MAXIMUM_SUBGROUP_COUNT>; // overflow means that all but 

// 256 * 256 = 65536  workgroups for 2^24 entities
@compute @workgroup_size(256) fn local_accumulation(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    let workgroup_index = workgroup_id.y * workgroup_id.z;
    let entity_vector = entity_buffer_0[workgroup_index * 256 + local_id];

    var chunk_byte: u32;
    if (BYTE_SHIFT == 0u) {
        chunk_byte = ((entity_vector.x & 0x1Fu) << 3) + (entity_vector.y >> 29);
    } else {
        chunk_byte = 0xFFu & (entity_vector.x >> (5 + 8 * BYTE_SHIFT));
    }

    var havent_finished = true;
    while (havent_finished) {
        if (chunk_byte == subgroupBroadcastFirst(chunk_byte)) {
            let total = subgroupAdd(1u);
            if (subgroupElect()) { shared_prefix[subgroup_id][chunk_byte >> 4][(chunk_byte >> 2) & 3u] += total << (8 * (chunk_byte & 3u)); }
            havent_finished = false;
        }
    } workgroupBarrier();

    if (subgroup_size > 8u) { // later split this function into two to check which subgroup size the compiler decides to use
        let this_increment: vec4u = shared_prefix[sub_id][subgroup_id]; 
        var total = subgroupAdd(select(vec4u(0, 0, 0, 0), this_increment, sub_id < subgroup_size));
        
        let vector_index = (sub_id >> 2) & 3u;
        let integer_shift = 8 * (sub_id & 3u);
        var final_value = (total[vector_index] >> integer_shift) & 0xFFu;
        
        let is_final_zero = final_value == 0u;
        let is_this_zero = ((this_increment[vector_index] >> integer_shift) & 0xFFu) == 0u;
        let is_overflow = is_final_zero && !is_this_zero;
        
        if (subgroupAny(is_overflow)) { // the thread with the overflow has to share the same vec4u aka be in the same subgroup
            workgroup_histogram[workgroup_id.x + workgroup_id.y * 256][sub_id + subgroup_id * subgroup_size] = subgroupShuffleDown(final_value, 1u) * 256;
        } else {
            workgroup_histogram[workgroup_id.x + workgroup_id.y * 256][sub_id + subgroup_id * subgroup_size] = final_value;
        }

    } else { // 32 subgroups
        let vec4u_index = subgroup_id & 0xFu;
        let subgroup_shift = subgroup_id >> 4;
        let this_shift = subgroup_shift * 16 + sub_id * 2;
        let this_increment: vec4u = shared_prefix[this_shift][vec4u_index] + shared_prefix[this_shift + 1][vec4u_index];
        let total = subgroupAdd(this_increment);

        workgroupBarrier();
        if (subgroupElect()) { shared_prefix[subgroup_shift][vec4u_index] = total; }
        workgroupBarrier();

        var total: vec4u;
        if (subgroup_id < 16) {
            total = subgroupAdd(select(0u, shared_prefix[sub_id][subgroup_id], sub_id < 2));
            if (subgroupElect()) { shared_prefix[0][subgroup_id] = total; }
        } workgroupBarrier();

        if (subgroup_id >= 16) { total = shared_prefix[0][vec4u_index]; }
        workgroup_histogram[workgroup_id.x + workgroup_id.y * 256][(vec4u_index << 4) + (subgroup_shift << 3) + sub_id] = total[(subgroup_shift << 1) + (sub_id >> 2)] << (8 * (sub_id & 3u));
    }
}

// (256 *) 256 workgroups
@compute @workgroup_size(1, 256) fn global_accumulation(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) { 
    shared_prefix[local_id] = workgroup_histogram[global_invocation_id.y][workgroup_id.x];
    workgroupBarrier();

    for (var exponent = 0u; exponent <= 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id >= stride) {
            shared_prefix[
                (local_id         ) + (1 - (exponent & 1u)) * 256
            ] += shared_prefix[
                (local_id - stride) + (    (exponent & 1u)) * 256
            ];
        } workgroupBarrier();
    }

    workgroup_histogram[global_invocation_id.y][workgroup_id.x] = shared_prefix[local_id];
    if (local_id == 0) { global_histogram[workgroup_id.y][workgroup_id.x] = shared_prefix[255]; }
}


// 256 workgroups for each digit
override THREAD_COUNT: u32 = 256u >> (24 - ENTITY_COUNT_LOG2);
@compute @workgroup_size(THREAD_COUNT) fn global_prefix(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    shared_prefix[local_id] = global_histogram[local_id][workgroup_id.x];
    workgroupBarrier();

    for (var exponent = 0u; exponent <= 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id >= stride) {
            shared_prefix[
                (local_id         ) + (1 - (exponent & 1u)) * 256
            ] += shared_prefix[
                (local_id - stride) + (    (exponent & 1u)) * 256
            ];
        } workgroupBarrier();
    }

    global_histogram[local_id][workgroup_id.x] = shared_prefix[local_id];
}

// (256 *) 256 workgroups for each digit
@compute @workgroup_size(1, 256) fn local_prefix(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) { 
    let global_offset = global_histogram[workgroup_id.y][workgroup_id.x];
    workgroup_histogram[global_invocation_id.y][workgroup_id.x] += global_offset;
}

var<workgroup> digit_offset: atomic<u32>;

// (256 *) 256 * 256 = 65536 workgroups
@compute @workgroup_size(1, 256) fn rescatter(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    if (local_id < workgroup_id.x - 1) { atomicAdd(&digit_offset, global_histogram[255][workgroup_id.x]); }

    let workgroup_index = workgroup_id.y * workgroup_id.z;
    let entity_vector = entity_buffer_0[workgroup_index * 256 + local_id];

    var chunk_byte: u32;
    if (BYTE_SHIFT == 0u) {
        chunk_byte = ((entity_vector.x & 0x1Fu) << 3) + (entity_vector.y >> 29);
    } else {
        chunk_byte = 0xFFu & (entity_vector.x >> (5 + 8 * BYTE_SHIFT));
    }

    if (chunk_byte == workgroup_id.x) { shared_prefix[workgroup_id.x] = 1u; }
    workgroupBarrier();

    for (var exponent = 0u; exponent <= 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id >= stride) {
            shared_prefix[
                (local_id         ) + (1 - (exponent & 1u)) * 256
            ] += shared_prefix[
                (local_id - stride) + (    (exponent & 1u)) * 256
            ];
        } workgroupBarrier();
    }

    if (chunk_byte == workgroup_id.x) { 
        let local_offset = workgroup_histogram[workgroup_index][workgroup_id.x];
        var shared_offset = 0u; if (local_id != 0) { shared_offset = shared_prefix[local_id - 1]; }

        entity_buffer_1[atomicLoad(&digit_offset) + local_offset + shared_offset] = entity_vector;
    }
}