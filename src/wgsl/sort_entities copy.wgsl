@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> digit_prefix : array<array<u32, 16>>; // length 4,096 for 2^24 entities

// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

override BIT_SHIFT : u32 = 0; // four passes to get all 4 bits of 2 bytes

// digit0 ---------- digit1 ----------
// 01010101 01010101 01010101 01010101  
var<workgroup> shared_digit_prefix : array<array<u32, 512>, 8>;

var<private> private_accumulation : u32;

@compute @workgroup_size(512) fn accumulate(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i = 0u; i < 4; i++) {
        let entity_vector = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 512];
        let entity_type = entity_vector.x >> 23;

        if (entity_type != 0) {
            let digit = (entity_vector.x >> (7 + BIT_SHIFT)) & 0xFu;
            private_accumulation += 1u << (4 * digit);
        }
    }
    // if (workgroup_id.x == 0 && local_id == 1) {
    //     let i = 0u;
    //     let digit = 0u;
    // }

    for (var digit = 0u; digit < 16; digit++) {
        shared_digit_prefix[digit >> 1][local_id] += ((private_accumulation >> (4 * digit))  & 0xFu) << ((digit & 1u) * 16);
    }
    workgroupBarrier();

    for (var stride = 1u; stride < 512; stride <<= 1) {
        var temp: array<u32, 16>;
        for (var digit = 0u; digit < 16; digit++) { if (local_id >= stride) {
            temp[digit] = (shared_digit_prefix[digit >> 1][local_id - stride] >> ((digit & 1u) * 16)) & 0xFFFFu;
        } }
        workgroupBarrier();

        for (var digit = 0u; digit < 16; digit++) { if (local_id >= stride) {
            shared_digit_prefix[digit][local_id] += temp[digit] << ((digit & 1u) * 16);
        } }
        workgroupBarrier();
    }

    if (local_id < 16) { digit_prefix[workgroup_id.x][local_id] = (shared_digit_prefix[local_id >> 1][255] >> ((local_id & 1u) * 16)) & 0xFFFFu; }
}

override ENTITY_COUNT_LOG2 : u32 = 24u;
override NO_OF_ITERATIONS : u32 = 32u >> (24 - ENTITY_COUNT_LOG2);

var<workgroup> shared_workgroup_prefix : array<array<u32, 256>, 16>;

// 16 workgroup
@compute @workgroup_size(256) fn prefix_sum(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i = 0u; i < NO_OF_ITERATIONS; i++) {
        shared_workgroup_prefix[workgroup_id.x][local_id] += digit_prefix[local_id + i * 256][workgroup_id.x];
        workgroupBarrier();

        for (var stride = 1u; stride < 256; stride <<= 1) {
            var temp: u32;
            if (local_id >= stride) { temp = shared_workgroup_prefix[workgroup_id.x][local_id - stride] >> (); }
            workgroupBarrier();

            if (local_id >= stride) { shared_workgroup_prefix[workgroup_id.x][local_id] += temp; }
            workgroupBarrier();
        } digit_prefix[local_id + i * 256][workgroup_id.x] = shared_workgroup_prefix[workgroup_id.x][local_id];

        if (local_id == 0) { shared_workgroup_prefix[workgroup_id.x][0] = shared_workgroup_prefix[workgroup_id.x][255]; }
        workgroupBarrier();
        if (local_id != 0) { shared_workgroup_prefix[workgroup_id.x][local_id] = 0; }
        workgroupBarrier();
    }
}

var<private> private_prefix : array<u32, 16>;

@compute @workgroup_size(512) fn rescatter(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    var sum_so_far = 0u;
    for (var i = 0u; i < 4; i++) {
        let entity_vector = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 512];
        let entity_type = entity_vector.x >> 23;

        if (entity_type != 0) {
            let digit = (entity_vector.x >> (7 + BIT_SHIFT)) & 0xFu;
            sum_so_far += 1u << (digit * 4);
            private_prefix[i] = sum_so_far;
        }
    }

    for (var digit = 0u; digit < 16; digit++) { shared_digit_prefix[digit][local_id] += (private_prefix[7] >> (4 * digit)) & 0xFu; }
    workgroupBarrier();

    for (var stride = 1u; stride < 512; stride <<= 1) {
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
        digit_offset += select(digit_prefix[array_size - 1][digit - 1], 0, digit == 0);
        let global_offset = digit_prefix[workgroup_id.x][digit];
        let local_offset = select(shared_digit_prefix[digit][local_id >> 1], 0, local_id == 0);

        for (var i = 0u; i < 8; i++) {
            let index = digit_offset + global_offset + local_offset + private_accumulation[digit];
            let entity_vector = entity_buffer_0[workgroup_id.x * 2048 + local_id + i * 512];
            
            if (entity_vector.x >> 23 != 0u) {
                entity_buffer_1[index] = entity_vector;
            }
        }
    }
}