@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> digit_prefix : array<array<u32, 16>>; // length 8192 for 2^24 entities

// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override BIT_SHIFT : u32 = 0; // four passes to get all 4 bits of 2 bytes

var<workgroup> shared_digit_prefix : array<array<u32, 256>, 4>;

var<private> private_accumulation : vec2u;

@compute @workgroup_size(256) fn accumulate(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i = 0u; i < 8; i++) {
        let entity_vector = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 256];
        let entity_type = entity_vector.x >> 23;

        if (entity_type != 0) {
            let digit = (entity_vector.x >> (7 + BIT_SHIFT)) & 0xFu;
            let accumulated = private_accumulation[digit >> 3] >> (4 * (digit & 7u));

            if (accumulated == 8u) { shared_digit_prefix[digit >> 2][local_id] = 8u << ((digit & 3u) * 8);}
            private_accumulation[digit >> 3] = (accumulated & 7u) <<  (4 * (digit & 7u));
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

    for (var digit = 0u; digit < 16; digit++) {
        let total_accumulation = (private_accumulation[digit >> 3] >> (4 * (digit & 7u))) & 0xFu;
        shared_digit_prefix[digit >> 2][local_id] += total_accumulation << ((digit & 3u) * 8);
    }
    workgroupBarrier();
 
    // for (var digit = 0u; digit < 16; digit++) {
    //     digit_prefix[local_id][digit] = shared_digit_prefix[digit][local_id];
    // } workgroupBarrier();

    for (var stride = 1u; stride < 256; stride <<= 1) {
        var temp: array<u32, 4>;
        for (var digit = 0u; digit < 16; digit++) { if (local_id >= stride) {
            temp[digit] += shared_digit_prefix[digit >> 2][local_id - stride] << ((digit & 3u) * 8);
        } }
        workgroupBarrier();

        for (var digit = 0u; digit < 16; digit++) { if (local_id >= stride) {
            shared_digit_prefix[digit][local_id] += (temp[digit] >> ((digit & 3u) * 8)) & 0xFFu;
        } }
        workgroupBarrier();

    }


    if (local_id < 16) { digit_prefix[workgroup_id.x][local_id] = (shared_digit_prefix[local_id >> 2][255] >> ((local_id & 3u) * 8)) & 0xFFu; }
}

override ENTITY_COUNT_LOG2 : u32 = 24u;
override NO_OF_ITERATIONS : u32 = 32u >> (24 - ENTITY_COUNT_LOG2);

var<workgroup> shared_prefix_sum : array<array<u32, 256>, 16>;

// 16 workgroup
@compute @workgroup_size(256) fn prefix_sum(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i = 0u; i < NO_OF_ITERATIONS; i++) {
        let global_index = local_id + workgroup_id.x * 256;
        shared_prefix_sum[workgroup_id.x][local_id] += digit_prefix[global_index][workgroup_id.x];
        workgroupBarrier();

        for (var stride = 1u; stride < 256; stride <<= 1) {
            var temp: u32;
            if (local_id >= stride) { temp = shared_prefix_sum[workgroup_id.x][local_id - stride]; }
            workgroupBarrier();

            if (local_id >= stride) { shared_prefix_sum[workgroup_id.x][local_id] += temp; }
            workgroupBarrier();
        } digit_prefix[global_index][workgroup_id.x] = shared_prefix_sum[workgroup_id.x][local_id];

        if (local_id == 0) { shared_prefix_sum[workgroup_id.x][0] = shared_prefix_sum[workgroup_id.x][255]; }
        workgroupBarrier();
        if (local_id != 0) { shared_prefix_sum[workgroup_id.x][local_id] = 0; }
        workgroupBarrier();
    }
}

var<private> private_prefix : array<vec2u, 8>;

@compute @workgroup_size(256) fn rescatter(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    var sum_so_far = vec2u(0, 0);
    for (var i = 0u; i < 8; i++) {
        let entity_vector = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 256];
        let entity_type = entity_vector.x >> 23;

        if (entity_type != 0) {
            let digit = (entity_vector.x >> (7 + BIT_SHIFT)) & 0xFu;
            sum_so_far[digit >> 3] += 1u << ((digit & 7u) * 4);
            private_prefix[i] = sum_so_far;
        }
    }
    

    for (var digit = 0u; digit < 16; digit++) {
        let total_accumulation = (private_accumulation[digit >> 2] >> ((digit & 3u) * 4)) & 0xFu;
        shared_digit_prefix[digit >> 2][local_id] += total_accumulation << ((digit & 3u) * 8);
    } workgroupBarrier();

    for (var stride = 1u; stride < 256; stride <<= 1) {
        var temp: array<u32, 4>;
        for (var digit = 0u; digit < 16; digit++) {  if (local_id >= stride) {
            temp[digit >> 2] += shared_digit_prefix[digit >> 2][local_id - stride] & (0xFFu << ((digit & 3u) * 8));
        } } workgroupBarrier();

        for (var digit = 0u; digit < 16; digit++) { if (local_id >= stride) {
            shared_digit_prefix[digit >> 2][local_id] += temp[digit >> 2] & (0xFFu << ((digit & 3u) * 8));
        } } workgroupBarrier();
    }

    let array_size = arrayLength(&digit_prefix);
    var digit_offset = 0u;

    for (var digit = 0u; digit < 16; digit++) {
        digit_offset += select(digit_prefix[array_size - 1][digit - 1], 0, digit == 0);
        let global_offset = digit_prefix[workgroup_id.x][digit];
        let local_offset = select((shared_digit_prefix[digit >> 2][local_id - 1] >> ((digit & 3u) * 8)) & 0xFFu, 0, local_id == 0);

        for (var i = 0u; i < 8; i++) {
            let index = digit_offset + global_offset + local_offset + private_accumulation[digit];
            let entity_vector = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 256];
            
            if (entity_vector.x >> 23 != 0u) {
                entity_buffer_1[index] = entity_vector;
            }
        }
    }
}