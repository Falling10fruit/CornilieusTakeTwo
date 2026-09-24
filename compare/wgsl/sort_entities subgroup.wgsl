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
override SHARED_PREFIX_SIZE : u32 = 256u / MINIMUM_SUBGROUP_SIZE;
var<workgroup> shared_prefix : array<array<vec4u, 16>, SHARED_PREFIX_SIZE>; // 32 * 16 * 4 * 4 = 8192/2^10
var<workgroup> shared_prefix_8 : array<array<vec2u, 32>, 32>;

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

    if (subgroup_size > 8u) {
        var havent_finished = true;
        while (havent_finished) {
            if (chunk_byte == subgroupBroadcastFirst(chunk_byte)) {
                let total = subgroupAdd(1u);
                if (subgroupElect()) { shared_prefix[subgroup_id][chunk_byte >> 4][(chunk_byte >> 2) & 3u] += total << (8 * (chunk_byte & 3u)); }
                havent_finished = false;
            }
        } workgroupBarrier();

        let this_increment = shared_prefix[sub_id][subgroup_id];
        var total = subgroupAdd(select(0u, this_increment, sub_id < subgroup_size));
        
        let vector_index = (sub_id >> 2) & 3u;
        let integer_shift = 8 * (sub_id & 3u);
        let greater_than_0_mask = 0xFFu * u32((this_increment[vector_index] >> integer_shift) == 0u); // 1111^0000 ; 0000^1010
        let final_value = (total[vector_index] >> integer_shift) & 0xFFu;
        workgroup_histogram[workgroup_id.x + workgroup_id.y * 256][sub_id + subgroup_id * subgroup_size] = final_value ^ greater_than_0_mask;
    } else { // 32 subgroups
        var havent_finished = true;
        while (havent_finished) {
            if (chunk_byte == subgroupBroadcastFirst(chunk_byte)) {
                let total = subgroupAdd(1u);
                if (subgroupElect()) { shared_prefix[subgroup_id][chunk_byte >> 4][(chunk_byte >> 2) & 3u] += total << (8 * (chunk_byte & 3u)); } // GOOD MORNING YOGA, PLEASE MAKE THIS IF BRANCH USE SHARED_PREFIX_8
                havent_finished = false;
            }
        } workgroupBarrier();

        var totals: array<vec4u, 4>;
        for (var i = 0u; i < 4; i++) { if (subgroup_id < 16) {
            totals[i] = subgroupAdd(shared_prefix[sub_id + i * subgroup_size][subgroup_id]);
        }}

        let total_index = (subgroup_id >> 1) & 3u;
        let vector_index = ((subgroup_id & 1u) << 1u) + (sub_id >> 2);
        let greater_than_0_mask = (total[vector_index] >> integer_shift) & 0xFFu;
        let final_value = totals[total_index][vector_index] << (8 * (sub_id & 3u));
        workgroup_histogram[workgroup_id.x + workgroup_id.y * 256][sub_id + subgroup_id * subgroup_size] = ;
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