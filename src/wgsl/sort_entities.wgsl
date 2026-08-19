@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> digit_prefix : array<array<u32, 16>>; // length 8192 for 2^24 entities
@group(1) @binding(1) var<storage, read_write> global_prefix : array<array<u32, 16>>; // length 32 for 2^24 entities (8192 / 256)

// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override BIT_SHIFT : u32 = 0; // four passes to get all 4 bits of 2 bytes

var<workgroup> shared_digit_prefix : array<array<u32, 256>, 16>;

var<private> private_accumulation : vec2u;

@compute @workgroup_size(256) fn accumulate( // 8192 workgroups for 2^24 entities
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i = 0u; i < 8; i++) {
        let entity_vector = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 256];
        let entity_type = entity_vector.x >> 23;

        if (entity_type != 0) {
            let digit = (entity_vector.x >> (7 + BIT_SHIFT)) & 0xFu;
            private_accumulation[digit >> 3] += 1u << (4 * (digit & 7u));
        }
    }
    // if (workgroup_id.x == 0 && local_id == 1) {
    //     let i = 0u;
    //     let digit = 0u;
    //     // debug_buffer = private_accumulation.x;
    //     debug_buffer = private_accumulation[digit >> 3] >> (4 * (digit & 7u));
    //     // debug_buffer = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 256].x;
    //     // debug_buffer = (entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 256].x >> (7 + BIT_SHIFT)) & 0xFu;
    //     // debug_buffer = workgroup_id.x * 2048 + local_id + i * 256;
    // }
// .w. :p

    for (var digit = 0u; digit < 16; digit++) {
        shared_digit_prefix[digit][local_id] += (private_accumulation[digit >> 3] >> (4 * (digit & 7u))) & 0xFu;
    }
    workgroupBarrier();
 
    // for (var digit = 0u; digit < 16; digit++) {
    //     digit_prefix[local_id][digit] = shared_digit_prefix[digit][local_id];
    // } workgroupBarrier();

    for (var stride = 1u; stride < 256; stride <<= 1) {
        var temp: array<u32, 16>;
        for (var digit = 0u; digit < 16; digit++) { if (local_id >= stride) {
            temp[digit] = shared_digit_prefix[digit][local_id - stride];
        } }
        workgroupBarrier();

        for (var digit = 0u; digit < 16; digit++) { if (local_id >= stride) {
            shared_digit_prefix[digit][local_id] += temp[digit];
        } }
        workgroupBarrier();

    }

    let array_length = arrayLength(&digit_prefix);
    if (local_id < 16) { digit_prefix[workgroup_id.x][local_id] = shared_digit_prefix[local_id][255]; }
}

override ENTITY_COUNT_LOG2 : u32 = 24u;

// 32 * 16 workgroups. A work group for every 256 chunk in the 8192 length buffer
@compute @workgroup_size(256) fn local_prefix_sum(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    shared_digit_prefix[workgroup_id.y][local_id] += select(digit_prefix[global_invocation_id.x][workgroup_id.y], 0u, global_invocation_id.x == 0);
    workgroupBarrier();

    for (var stride = 1u; stride < 256; stride <<= 1) {
        var temp: u32;
        if (local_id >= stride) { temp = shared_digit_prefix[workgroup_id.y][local_id - stride]; }
        workgroupBarrier();

        if (local_id >= stride) { shared_digit_prefix[workgroup_id.y][local_id] += temp; }
        workgroupBarrier();
    }
    
    let final_accumulation = shared_digit_prefix[workgroup_id.y][local_id];
    digit_prefix[global_invocation_id.x][workgroup_id.x] = final_accumulation;
    if (local_id == 0u) { global_prefix[workgroup_id.x][workgroup_id.y] = final_accumulation; }
}

override GLOBAL_PREFIX_SUM_LENGTH : u32 = 32u >> (24 - ENTITY_COUNT_LOG2); // how many numbers to run a prefix sum over
override EXPONENT_ITERATIONS_COUNT : u32 = countTrailingZeros(GLOBAL_PREFIX_SUM_LENGTH);
override SHARED_ARRAY_WORKGROUP_SHIFT : u32 = GLOBAL_PREFIX_SUM_LENGTH * (EXPONENT_ITERATIONS_COUNT + 1); // Or how big is the allocated memory on the shared array for each workgroup
var<workgroup> shared_global_prefix_sum_array : array<u32, SHARED_ARRAY_WORKGROUP_SHIFT * 16>;
// 16 workgroups
@compute @workgroup_size(GLOBAL_PREFIX_SUM_LENGTH) fn global_prefix_sum(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    shared_global_prefix_sum_array[workgroup_id.x * SHARED_ARRAY_WORKGROUP_SHIFT + local_id] = global_prefix[workgroup_id.x][local_id];

    workgroupBarrier();
 
    // first element is zero so the last iteration would increment by nothing
    for (var exponent: u32 = 1u; exponent < EXPONENT_ITERATIONS_COUNT; exponent += 1) { 
        let stride = 1u << exponent; if (local_id > stride) {
            shared_global_prefix_sum_array[
                workgroup_id.x * SHARED_ARRAY_WORKGROUP_SHIFT +
                (local_id         ) + (exponent + 1) * GLOBAL_PREFIX_SUM_LENGTH
            ] += shared_global_prefix_sum_array[
                workgroup_id.x * SHARED_ARRAY_WORKGROUP_SHIFT +
                (local_id - stride) + (exponent    ) * GLOBAL_PREFIX_SUM_LENGTH
            ];
        } workgroupBarrier();
    }

    global_prefix[local_id][workgroup_id.x] = shared_global_prefix_sum_array[
        SHARED_ARRAY_WORKGROUP_SHIFT * workgroup_id.x +
        local_id + (EXPONENT_ITERATIONS_COUNT - 1) * GLOBAL_PREFIX_SUM_LENGTH];
}

// 32 * 16 workgroups. 255 threads because the first element of every chunk is the global prefix
@compute @workgroup_size(255) fn increment_by_global_prefix(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let global_index = workgroup_id.x * 256 + 1 + local_id;
    digit_prefix[global_index][workgroup_id.y] += global_prefix[workgroup_id.x * 256][workgroup_id.y];
}


var<private> private_prefix : array<vec2u, 8>;
// test if it's better to use private or shared + private memory
var<private> entity_vectors : array<vec4u, 8>;

@compute @workgroup_size(256) fn rescatter(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    var sum_so_far = vec2u(0, 0);
    for (var i = 0u; i < 8; i++) {
        entity_vectors[i] = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 256];
        let entity_type = entity_vectors[i].x >> 23;

        if (entity_type != 0) {
            let digit = (entity_vectors[i].x >> (7 + BIT_SHIFT)) & 0xFu;
            sum_so_far[digit >> 3] += 1u << ((digit & 7u) * 4);
            private_prefix[i] = sum_so_far;
        }
    }

    for (var digit = 0u; digit < 16; digit++) { shared_digit_prefix[digit][local_id] += private_accumulation[digit]; }
    workgroupBarrier();

    for (var stride = 1u; stride < 256; stride <<= 1) {
        var temp: array<u32, 16>;
        for (var digit = 0u; digit < 16; digit++) { 
            if (local_id >= stride) { temp[digit] = shared_digit_prefix[digit][local_id - stride]; }
        }
        workgroupBarrier();

        for (var digit = 0u; digit < 16; digit++) {
            if (local_id >= stride) { shared_digit_prefix[digit][local_id] += temp[digit]; }
        }
        workgroupBarrier();
    }

    let array_size = arrayLength(&digit_prefix);
    var digit_offset = 0u;

    for (var digit = 0u; digit < 16; digit++) {
        digit_offset += select(digit_prefix[array_size - 1][digit - 1], 0u, digit == 0);
        let global_offset = digit_prefix[workgroup_id.x][digit];
        let local_offset = select(shared_digit_prefix[digit][local_id], 0u, local_id == 0);

        for (var i = 0u; i < 8; i++) {
            let index = digit_offset + global_offset + local_offset + private_accumulation[digit];
            
            if (entity_vectors[i].x >> 23 != 0u) {
                entity_buffer_1[index] = entity_vectors[i];
            }
        }
    }
}