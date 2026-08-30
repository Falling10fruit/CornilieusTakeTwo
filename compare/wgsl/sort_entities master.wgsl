// type (2^11 = 2048)           chunk index 2^24         xPos(2^8)    yPos (2 * 16 pixels divided by 2^8)     rotation 2^13 
//  [ 01010101 010 ][ 10101 01010101 01010101 | 010 ][ 10101 010 ]             [ 10101 010 ]             [ 10101 01010101 ] |

@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> digit_prefix : array<array<u32, 256>>; // length 65536 for 2^24 entities (2^24)/256 = 65536 (64 MiB)
@group(1) @binding(1) var<storage, read_write> global_prefix : array<array<u32, 256>>; // length 256 for 2^24 entities (65536 / 256)
// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override BYTE_SHIFT : u32 = 0; // 0 -> 2
override ENTITY_COUNT_LOG2 : u32 = 24u;

var<workgroup> shared_digit : array<atomic<u32>, 256>;
// 65536 workgroups for 2^24 entities
@compute @workgroup_size(256) fn local_accumulation( 
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let entity_vector = entity_buffer_0[global_invocation_id.y];
    
    var chunk_byte: u32;
    if (BYTE_SHIFT == 0u) {
        chunk_byte = ((entity_vector.x & 0x1Fu) << 3) + (entity_vector.y >> 29);
    } else {
        chunk_byte = 0xFFu & (entity_vector.x >> (5 + 8 * BYTE_SHIFT));
    }

    atomicAdd(&(shared_digit[chunk_byte]), 1u);
    workgroupBarrier();
    digit_prefix[workgroup_id.x][local_id] = atomicLoad(&(shared_digit[local_id]));
}

var<workgroup> shared_accumulation : array<u32, 2048>;
// 256 (* 256) workgroups for 2^24 entities. A work group for every 256 chunk
@compute @workgroup_size(256) fn global_accumulation(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    shared_accumulation[local_id] = digit_prefix[global_invocation_id.x][workgroup_id.y];
    workgroupBarrier();

    for (var exponent = 1u; exponent < 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id > stride) {
            shared_accumulation[
                (local_id         ) + (exponent    ) * 256
            ] += shared_accumulation[
                (local_id - stride) + (exponent - 1) * 256
            ];
        } workgroupBarrier();
    }

    digit_prefix[global_invocation_id.x][workgroup_id.y] = shared_accumulation[1792 + local_id];
    if (local_id == 0) { global_prefix[workgroup_id.x][workgroup_id.y] = shared_accumulation[2047]; }
}

// TEST if it's better to have a smaller shared memory but bottleneck with workgroup barriers
override GLOBAL_PREFIX_SUM_ITERATION_COUNT : u32 = 8 - (24 - ENTITY_COUNT_LOG2);
override GLOBAL_PREFIX_SUM_SHARED_ARRAY_CHUNK_LENGTH : u32 = 256u >> (24 - ENTITY_COUNT_LOG2);
override GLOBAL_PREFIX_SUM_SHARED_ARRAY_LENGTH : u32 = GLOBAL_PREFIX_SUM_ITERATION_COUNT * GLOBAL_PREFIX_SUM_SHARED_ARRAY_CHUNK_LENGTH;
var<workgroup> global_prefix_sum_shared_array : array<u32, GLOBAL_PREFIX_SUM_SHARED_ARRAY_LENGTH>;
// 256 workgroups
@compute @workgroup_size(GLOBAL_PREFIX_SUM_SHARED_ARRAY_CHUNK_LENGTH) fn global_prefix_sum(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    global_prefix_sum_shared_array[local_id] = global_prefix[local_id][workgroup_id.x];
    workgroupBarrier();

    for (var exponent = 1u; exponent < GLOBAL_PREFIX_SUM_ITERATION_COUNT; exponent += 1) { 
        let stride = 1u << exponent; if (local_id > stride) {
            global_prefix_sum_shared_array[
                (local_id         ) + (exponent    ) * GLOBAL_PREFIX_SUM_SHARED_ARRAY_CHUNK_LENGTH
            ] += global_prefix_sum_shared_array[
                (local_id - stride) + (exponent - 1) * GLOBAL_PREFIX_SUM_SHARED_ARRAY_CHUNK_LENGTH
            ];
        } workgroupBarrier();
    }

    global_prefix[local_id][workgroup_id.x] = global_prefix_sum_shared_array[GLOBAL_PREFIX_SUM_SHARED_ARRAY_LENGTH - GLOBAL_PREFIX_SUM_SHARED_ARRAY_CHUNK_LENGTH + local_id];
}

var<workgroup> local_prefix_sum_shared_array : array<u32, 2048>; // 256 * 8
// 256 (* 256) workgroups for 2^24 entities
@compute @workgroup_size(256) fn local_prefix_sum(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    // local_prefix_sum_shared_array[local_id] = digit_prefix[global_invocation_id.x][workgroup_id.y];
    // workgroupBarrier();

    for (var exponent = 1u; exponent < 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id > stride) {
            local_prefix_sum_shared_array[
                (local_id         ) + (exponent    ) * 256
            ] += global_prefix_sum_shared_array[
                (local_id - stride) + (exponent - 1) * 256
            ];
        } workgroupBarrier();
    }

    var global_increment: u32;
    if (workgroup_id.x == 0) { global_increment = 0; }
    else { global_increment = global_prefix[workgroup_id.x - 1][workgroup_id.y]; }

    //                                                                                  256 * 7
    digit_prefix[global_invocation_id.x][workgroup_id.y] = local_prefix_sum_shared_array[1792 + local_id] + global_increment;
}

var<workgroup> digit_offset : atomic<u32>;
// 65536 (* 256) workgroups for 2^24 entities
@compute @workgroup_size(256) fn rescatter(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    if (local_id < workgroup_id.y) { atomicAdd(&digit_offset, global_prefix[arrayLength(&global_prefix) - 1][local_id]); }

    let entity_vector = entity_buffer_0[global_invocation_id.x];

    var chunk_byte: u32;
    if (BYTE_SHIFT == 0u) {
        chunk_byte = ((entity_vector.x & 0x1Fu) << 3) + (entity_vector.y >> 29);
    } else {
        chunk_byte = 0xFFu & (entity_vector.x >> (5 + 8 * BYTE_SHIFT));
    }

    if (chunk_byte == workgroup_id.y) { local_prefix_sum_shared_array[local_id] = 1u; };
    workgroupBarrier();
    
    for (var exponent = 1u; exponent < 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id > stride) {
            local_prefix_sum_shared_array[
                (local_id         ) + (exponent    ) * 256
            ] += global_prefix_sum_shared_array[
                (local_id - stride) + (exponent - 1) * 256
            ];
        } workgroupBarrier();
    }

    if (chunk_byte == workgroup_id.y) {
        var global_increment: u32;
        if (workgroup_id.x == 0) { global_increment = 0u; }
        else { global_increment = digit_prefix[workgroup_id.x - 1][chunk_byte]; } // TODO figure out which digit I'm supposed to use.

        entity_buffer_1[atomicLoad(&digit_offset) + global_increment + select(local_prefix_sum_shared_array[1792 + local_id - 1], 0u, local_id == 0)] = entity_vector;
    }
}