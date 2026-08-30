// type (2^11 = 2048)           chunk index 2^24         xPos(2^8)    yPos (2 * 16 pixels divided by 2^8)     rotation 2^13 
//  [ 01010101 010 ][ 10101 01010101 01010101 | 010 ][ 10101 010 ]             [ 10101 010 ]             [ 10101 01010101 ] |

@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> workgroup_histogram : array<array<u32, 256>>; // length 65536 for 2^24 entities (2^24)/256 = 65536 (64 MiB)
@group(1) @binding(1) var<storage, read_write> global_histogram : array<array<u32, 256>>; // length 256
// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override BYTE_SHIFT : u32 = 0; // 0 -> 2
override ENTITY_COUNT_LOG2 : u32 = 24u; // only down to 20

var<workgroup> shared_prefix : array<u32, 512>;
// (256 *) 256 * 256 = 65536  workgroups for 2^24 entities
@compute @workgroup_size(1, 256) fn local_accumulation(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
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

    if (local_id == 0) { workgroup_histogram[workgroup_index][workgroup_id.x] = shared_prefix[255]; }
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
@compute @workgroup_size(256) fn global_prefix(
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