@group(1) @binding(0) var<storage, read_write> digit_prefix : array<array<u32, 16>>; // length 8192 for 2^24 entities

override ENTITY_COUNT_LOG2 : u32 = 24;
override PREFIX_ITERATION_COUNT : u32 = 32u >> (24 - ENTITY_COUNT_LOG2);

var<workgroup> shared_prefix : array<array<u32, 16>, 256>;

@compute @workgroup_size(256) fn chunk_prefix( 
    @builtin(local_invocation_index) local_id : u32,
) {
    for (var i = 0u; i < PREFIX_ITERATION_COUNT; i++) { for (var digit = 0u; digit < 16; digit++) {
        shared_prefix[local_id][digit] += digit_prefix[local_id + i * 256][digit];
        workgroupBarrier();

        for (var stride = 1u; stride <= 256; stride <<= 1) {
            var temp : u32;
            if (local_id >= stride) { temp = shared_prefix[local_id - stride][digit]; }
            workgroupBarrier();

            if (local_id >= stride) { shared_prefix[local_id][digit] += temp; }
            workgroupBarrier();
        }

        if (local_id < 16) { shared_prefix[0][local_id] = shared_prefix[255][local_id]; }
        workgroupBarrier();
        for (var digit = 0u; digit < 16; digit++) { if (local_id != 0) { shared_prefix[local_id][digit] = 0; } }
        workgroupBarrier();
    } }

    for (var i = 1u; i < 4; i++) {
        let stride = 1u << i;
        
        if (local_id >= stride) {
            let temp = shared_prefix[i - 1][local_id - stride];
            shared_prefix[i][local_id] += temp;
        }

        workgroupBarrier();
    }


    if (local_id < 16) {
        digit_prefix[0][local_id] = select(shared_prefix[3][local_id - 1], 0, local_id == 0);
    }
}