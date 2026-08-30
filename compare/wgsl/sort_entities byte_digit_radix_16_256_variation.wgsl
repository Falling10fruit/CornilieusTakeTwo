// type (2^11 = 2048)           chunk index 2^24         xPos(2^8)    yPos (2 * 16 pixels divided by 2^8)     rotation 2^13 
//  [ 01010101 010 ][ 10101 01010101 01010101 | 010 ][ 10101 010 ]             [ 10101 010 ]             [ 10101 01010101 ] |

@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> workgroup_prefix : array<array<u32, 256>>; // length 4096 for 2^24 entities (2^24)/256 = 65536 (64 MiB)
@group(1) @binding(1) var<storage, read_write> digit_prefix : array<u32>; // length 256 for every digit
// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override BYTE_SHIFT : u32 = 0; // 0 -> 2
override ENTITY_COUNT_LOG2 : u32 = 24u; // only down to 20
override ITERATION_COUNT : u32 = 16u >> (24 - ENTITY_COUNT_LOG2);

var<workgroup> shared_prefix : array<u32, 512>;
// (256 *) 4,096  workgroups for 2^24 entities
@compute @workgroup_size(256) fn local_accumulation( 
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let offset = workgroup_id.y * 256 * ITERATION_COUNT + local_id;
    var accumulation = 0u;
    for (var i = 0u; i < ITERATION_COUNT; i++) {
        let entity_vector = entity_buffer_0[offset + i * 256];

        var chunk_byte: u32;
        if (BYTE_SHIFT == 0u) {
            chunk_byte = ((entity_vector.x & 0x1Fu) << 3) + (entity_vector.y >> 29);
        } else {
            chunk_byte = 0xFFu & (entity_vector.x >> (5 + 8 * BYTE_SHIFT));
        }

        if (chunk_byte == workgroup_id.x) { accumulation += 1u; }
    } shared_prefix[local_id] = accumulation;
    workgroupBarrier();

    for (var exponent = 0u; exponent < 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id > stride) {
            shared_prefix[
                (local_id         ) + (1 - (exponent & 1u)) * 256
            ] += shared_prefix[
                (local_id - stride) + (    (exponent & 1u)) * 256
            ];
        } workgroupBarrier();
    }

    if (local_id == 0) { workgroup_prefix[workgroup_id.y][workgroup_id.x] = shared_prefix[255]; }
}

// 256 workgroups for each digit
@compute @workgroup_size(256) fn global_prefix(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) { 
    var private_prefix: array<u32, 16>;
    var accumulation = 0u;
    for (var i = 0u; i < 16; i++) { // 256 * 16
        accumulation += workgroup_prefix[local_id + i * 256][workgroup_id.x];
        private_prefix[i] = accumulation;
    } shared_prefix[local_id] = accumulation;
    workgroupBarrier();

    for (var exponent = 0u; exponent < 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id > stride) {
            shared_prefix[
                (local_id         ) + (1 - (exponent & 1u)) * 256
            ] += shared_prefix[
                (local_id - stride) + (    (exponent & 1u)) * 256
            ];
        } workgroupBarrier();
    }

    for (var i = 0u; i < 16; i++) {
        workgroup_prefix[local_id + i * 256][workgroup_id.x] = shared_prefix[local_id] + private_prefix[i];
    }

    if (local_id == 0) { digit_prefix[workgroup_id.x] = shared_prefix[255]; }
}

// (256 *) 4,096 workgroups for 2^24 entities
@compute @workgroup_size(256) fn rescatter(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let offset = workgroup_id.y * 256 * ITERATION_COUNT + local_id;

    var entity_vectors: array<vec4u, 16>; // wgsl can't override private array length
    var private_prefix_length = 0u;
    for (var i = 0u; i < ITERATION_COUNT; i++) {
        let entity_vector = entity_buffer_0[offset + i * 256];

        var chunk_byte: u32;
        if (BYTE_SHIFT == 0u) {
            chunk_byte = ((entity_vector.x & 0x1Fu) << 3) + (entity_vector.y >> 29);
        } else {
            chunk_byte = 0xFFu & (entity_vector.x >> (5 + 8 * BYTE_SHIFT));
        }

        if (chunk_byte == workgroup_id.x) {
            entity_vectors[private_prefix_length] = entity_vector;
            private_prefix_length += 1u;
        }
    } shared_prefix[local_id] = private_prefix_length;
    workgroupBarrier();
    
    for (var exponent = 0u; exponent < 8; exponent += 1) {
        let stride = 1u << exponent; if (local_id > stride) {
            shared_prefix[
                (local_id         ) + (1 - (exponent & 1u)) * 256
            ] += shared_prefix[
                (local_id - stride) + (    (exponent & 1u)) * 256
            ];
        } workgroupBarrier();
    }
    
    var digit_offset: u32;
    if (workgroup_id.x == 0) { digit_offset = 0; }
    else { digit_offset = digit_prefix[workgroup_id.x - 1]; }

    var workgroup_offset: u32;
    if (workgroup_id.y == 0) { workgroup_offset = 0; }
    else { workgroup_offset = workgroup_prefix[workgroup_id.y - 1][workgroup_id.x]; }

    for (var i = 0u; i < private_prefix_length; i++) { entity_buffer_1[digit_offset + workgroup_offset + i] = entity_vectors[i]; }
}


// 1 4 7  2  5  8  3  6  9
// 1 5 12 14 19 27 30 36 45
// thread 1: 1 2 3 -> 1  3  6
// thread 2: 4 5 6 -> 4  9  15
// thread 3: 7 8 9 -> 7  15 24
// global prefix: 6 21 45
// thread 1: 1  3  6  -> 1 9 27
// thread 2: 4  9  15 -> 4 15 31
// thread 3: 7  15 24 -> 7 21 45
// 1 4 7 9 1 5 21 27 31 45
// 1 4 7 2 5  8  3  6  9

// 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
// workgroup 0:
//  thread 0: 1  3  -> 4
//  thread 1: 2  4  -> 6
// workgroup 1:
//  thread 0: 5  7  -> 12
//  thread 1: 6  8  -> 14
// workgroup 2:
//  thread 0: 9  11 -> 20
//  thread 1: 10 12 -> 22
// workgroup 3:
//  thread 0: 13 15 -> 28
//  thread 1: 14 16 -> 30
// workgroup 4:
//  thread 0: 17 19 -> 36
//  thread 1: 18 20 -> 38
// workgroup 5:
//  thread 0: 21 23 -> 44
//  thread 1: 22 24 -> 46
// workgroup 6:
//  thread 0: 25 27 -> 52
//  thread 1: 26 28 -> 54
// workgroup 7:
//  thread 0: 29 31 -> 60
//  thread 1: 30 32 -> 62