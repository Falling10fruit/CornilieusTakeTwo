enable subgroups;
diagnostic(off, subgroup_uniformity);
// I have a lot of comments just to remind me how stuff I wrote works
// type (2^11 = 2048)           chunk index 2^24         xPos(2^8)    yPos (2 * 16 pixels divided by 2^8)     rotation 2^13 
//  [ 01010101 010 ][ 10101 01010101 01010101 | 010 ][ 10101 010 ]             [ 10101 010 ]             [ 10101 01010101 ] |

@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;
// wesl override
const ENTITY_COUNT_LOG2 : u32 = constants::ENTITY_COUNT_LOG2; // only down to 20
const WORKGROUP_HISTOGRAM_LENGTH = (1u << ENTITY_COUNT_LOG2) >> 8;
const GLOBAL_HISTOGRAM_LENGTH = WORKGROUP_HISTOGRAM_LENGTH >> 8;
@group(1) @binding(0) var<storage, read_write> workgroup_histogram : array<array<u32, WORKGROUP_HISTOGRAM_LENGTH>, 256>;
@group(1) @binding(1) var<storage, read_write> global_histogram : array<array<u32, GLOBAL_HISTOGRAM_LENGTH>, 256>;
@group(1) @binding(2) var<storage, read_write> digit_histogram : array<u32, 256>;
// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

@group(3) @binding(0) var<storage, read_write> read_subgroup_size : u32;

override BYTE_SHIFT : u32 = 0; // 0 -> 2

override IS_CHECKING_SUBGROUP_SIZE : bool = true;
override SUBGROUP_SIZE : u32 = 32u; // or 16
override SUBGROUP_COUNT : u32 = 256u / SUBGROUP_SIZE;

fn get_chunk_from_entity_vector(vector:vec4u) -> u32 {
    if (BYTE_SHIFT == 0u) {
        return ((vector.x & 0x1Fu) << 3) + (vector.y >> 29);
    } else {
        return 0xFFu & (vector.x >> (5 + 8 * BYTE_SHIFT));
    }
}

override LOCAL_ACCUMULATION_ITERATIONS = SUBGROUP_COUNT >> 2;
override DIGIT_COUNT = 256u / LOCAL_ACCUMULATION_ITERATIONS;
var<workgroup> shared_prefix : array<u32, DIGIT_COUNT * SUBGROUP_COUNT>;
fn index_shared_prefix(subgroup_id:u32, digit:u32) -> u32 {
    return shared_prefix[subgroup_id + digit * subgroup_id];
}
fn insert_shared_prefix(subgroup_id:u32, digit:u32, value:u32) {
    shared_prefix[subgroup_id + digit * subgroup_id] = value;
}

@compute @workgroup_size(256) fn local_accumulation(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_size) subgroup_size : u32,
    @builtin(subgroup_invocation_id) sub_id : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let workgroup_index = workgroup_id.x + workgroup_id.y * 256;
    let local_index = subgroup_id * subgroup_size + sub_id;

    let entity_vector = entity_buffer_0[workgroup_index * 256 + local_index];
    let chunk_byte = get_chunk_from_entity_vector(entity_vector);

    for (var sub_byte_offset = 0u; sub_byte_offset < LOCAL_ACCUMULATION_ITERATIONS; sub_byte_offset++) {
        let chunk_byte_relative = chunk_byte - DIGIT_COUNT * sub_byte_offset;
        
        var havent_finished = chunk_byte_relative < DIGIT_COUNT;
        while (subgroupAny(havent_finished)) {
            var is_active = false;
            if (havent_finished) {
                is_active = chunk_byte_relative == subgroupBroadcastFirst(chunk_byte_relative);
            }

            let digit_total = subgroupAdd(select(0u, 1u, is_active));
            if (subgroupElect()) { insert_shared_prefix(subgroup_id, chunk_byte_relative, digit_total); }
        }
        
        workgroupBarrier();
        let iter_count = DIGIT_COUNT/SUBGROUP_COUNT/4u; // 64 / 16 / 4
        let iter_shift = DIGIT_COUNT/iter_count;
        for (var i = 0u; i < iter_count; i++) {
            
            var this_accumulation = vec4u(0, 0, 0, 0);
            if (sub_id < SUBGROUP_COUNT) { this_accumulation = vec4u(
                index_shared_prefix(subgroup_id * 4 + 0, sub_id),
                index_shared_prefix(subgroup_id * 4 + 1, sub_id),
                index_shared_prefix(subgroup_id * 4 + 2, sub_id),
                index_shared_prefix(subgroup_id * 4 + 3, sub_id)
            ); }
            
            let total = subgroupAdd(this_accumulation);
            if (subgroupElect()) {
                let base_index = sub_byte_offset * DIGIT_COUNT + iter_shift * i + subgroup_id * 4;
                for (var total_index = 0u; total_index < 4; total_index++) {
                    workgroup_histogram[base_index + total_index][workgroup_index] = total[total_index];
                }
            }
        }
    }
}

var<workgroup> shared_prefix_8 : array<array<u32, 32>, 32>; // 32 * 32 * 4
@compute @workgroup_size(256) fn local_accumulation_8(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_size) subgroup_size : u32,
    @builtin(subgroup_invocation_id) sub_id : u32
) {
    let workgroup_index = workgroup_id.x + workgroup_id.y * 256;
    let local_index = subgroup_id * 8 + sub_id;

    let entity_vector = entity_buffer_0[workgroup_index * 256 + local_index];
    let chunk_byte = get_chunk_from_entity_vector(entity_vector);

    for (var sub_byte_offset = 0u; sub_byte_offset < 8; sub_byte_offset++) {
        let chunk_byte_relative = chunk_byte - 32 * sub_byte_offset;
        
        var havent_finished = chunk_byte_relative < 32;
        while (subgroupAny(havent_finished)) {
            var is_active = false;
            if (havent_finished) {
                is_active = chunk_byte_relative == subgroupBroadcastFirst(chunk_byte_relative);
            }

            let digit_total = subgroupAdd(select(0u, 1u, is_active));
            if (subgroupElect()) { insert_shared_prefix(subgroup_id, chunk_byte_relative, digit_total); }
        }
        
        workgroupBarrier();
        var this_accumulation = vec4u(
            index_shared_prefix(subgroup_id, sub_id * 4 + 0),
            index_shared_prefix(subgroup_id, sub_id * 4 + 1),
            index_shared_prefix(subgroup_id, sub_id * 4 + 2),
            index_shared_prefix(subgroup_id, sub_id * 4 + 3)
        );

        let total_vec4u = subgroupAdd(this_accumulation);
        let total_u32 = total_vec4u[0] + total_vec4u[1] + total_vec4u[2] + total_vec4u[3];
        if (subgroupElect()) {
            workgroup_histogram[sub_byte_offset * 32 + subgroup_id][workgroup_index] = total_u32;
        }
    }
}

var<workgroup> shared_prefix_2 : array<array<vec4u, 2>, SUBGROUP_COUNT>;
// 256 (* 16) workgroups
@compute @workgroup_size(256) fn global_accumulation(
    @builtin(workgroup_id) workgroup_id : vec3u, 
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;
    
    let digit = (workgroup_id.y << 4) + (local_index >> 4);
    var this_increment = vec4u(0, 0, 0, 0);
    var not_empty: bool = workgroup_histogram[digit][workgroup_id.x * 256 + (local_index & 0xFu)] > 0u; // I'm sure that the next time it'll request this on the first iteration it'll already be in cache so it wouldn't be that bad
    for (var stride = 0u; stride < 16; stride++) {
        let index = workgroup_id.x * 256 + (local_index & 0xFu) + stride * 16;
        this_increment[(digit >> 1) & 3u] += workgroup_histogram[digit][index] << (16 * (digit & 1u));
    }

    let is_overflow = (this_increment[(digit >> 1) & 3u] >> (16 * (digit & 3u)) == 0u && not_empty); 
    if (subgroupAny(is_overflow)) {
        if (is_overflow) { global_histogram[digit][workgroup_id.x] = 65536u; }
        return; // YOGA YOU NEED TO REMOVE THIS RETURN SO THAT WORKGROUPBARRIER OCCURS AT UNIFORM CONTROL FORM
    }

    let total = subgroupAdd(this_increment); // this increment can hold digits from 0-127 in case you were wondering if we have to isolate each digit's subgroup add
    if (subgroupElect()) { shared_prefix_2[subgroup_id][digit >> 3] = this_increment; }
    workgroupBarrier();

    let final_total: vec4u = subgroupAdd(select(vec4u(0, 0, 0, 0), shared_prefix_2[sub_id][local_index >> 7], sub_id < subgroup_size));
    if (sub_id < 8) {
        let this_total = final_total[(digit >> 1) & 3u] >> (16 * (digit & 1u));
        global_histogram[digit][workgroup_id.x] = this_total;
    }
} 

override SHARED_PREFIX_4_LENGTH: u32 = 256u / SUBGROUP_SIZE;
var<workgroup> shared_prefix_4 : array<u32, SHARED_PREFIX_4_LENGTH>;
// 256 workgroups for 256 digits
override ITERATION_COUNT: u32 = 16u >> (24 - ENTITY_COUNT_LOG2);
@compute @workgroup_size(256) fn global_prefix( // 0101-digit 0101-index 
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;

    let this_increment: u32 = global_histogram[workgroup_id.x][local_index];
    let this_prefix = subgroupExclusiveAdd(this_increment);
    let subgroup_max = subgroupMax(this_prefix) + this_increment;
    if (subgroupElect()) { shared_prefix_4[subgroup_id] = subgroup_max; }

    let subgroup_prefix: u32 = subgroupExclusiveAdd(select(0u, shared_prefix_4[sub_id], sub_id < SHARED_PREFIX_4_LENGTH));
    global_histogram[workgroup_id.x][local_index] = subgroup_prefix + this_increment;

    if (local_index == 255) { digit_histogram[workgroup_id.x] = subgroup_prefix + subgroup_max; }
}


// one workgroup
@compute @workgroup_size(256) fn digit_prefix(
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;

    let this_increment: u32 = digit_histogram[local_index];
    let this_prefix = subgroupExclusiveAdd(this_increment);
    let subgroup_max = subgroupMax(this_prefix) + this_increment;
    if (subgroupElect()) { shared_prefix_4[subgroup_id] = subgroup_max; }

    let subgroup_prefix: u32 = subgroupExclusiveAdd(select(0u, shared_prefix_4[sub_id], sub_id < SHARED_PREFIX_4_LENGTH));
    digit_histogram[local_index] = subgroup_prefix + this_increment;
}

var<workgroup> digit_offset: atomic<u32>;

// 256 * 256 = 65536  workgroups for 2^24 entities
@compute @workgroup_size(256) fn rescatter(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;
    
    let workgroup_index = workgroup_id.x + workgroup_id.y * 256;
    let entity_vector = entity_buffer_0[workgroup_index * 256 + local_index];
    let chunk_byte = get_chunk_from_entity_vector(entity_vector);

    for (var sub_byte_offset = 0u; sub_byte_offset < LOCAL_ACCUMULATION_ITERATIONS; sub_byte_offset++) {
        let chunk_byte_relative = chunk_byte - DIGIT_COUNT * sub_byte_offset;
        
        var havent_finished = chunk_byte_relative < DIGIT_COUNT;
        while (subgroupAny(havent_finished)) {
            var is_active = false;
            if (havent_finished) {
                is_active = chunk_byte_relative == subgroupBroadcastFirst(chunk_byte_relative);
            }

            let prefix_count = subgroupExclusiveAdd(select(0u, 1u, is_active));
            let total_count = subgroupMax(prefix_count) + 1;
            if (subgroupElect()) { insert_shared_prefix(subgroup_id, chunk_byte_relative, total_count); }
        }

        workgroupBarrier();
        let iter_count = DIGIT_COUNT/SUBGROUP_COUNT/4u; // 64 / 16 / 4
        let iter_shift = DIGIT_COUNT/iter_count;
        for (var i = 0u; i < iter_count; i++) {
            let base_digit = subgroup_id * 4;
            
            var this_accumulation = vec4u(0, 0, 0, 0);
            if (sub_id < SUBGROUP_COUNT) { this_accumulation = vec4u(
                index_shared_prefix(sub_id, base_digit + 0),
                index_shared_prefix(sub_id, base_digit + 1),
                index_shared_prefix(sub_id, base_digit + 2),
                index_shared_prefix(sub_id, base_digit + 3)
            ); }

            let prefix = subgroupExclusiveAdd(this_accumulation);
            insert_shared_prefix(sub_id, base_digit + 0, prefix[0]);
            insert_shared_prefix(sub_id, base_digit + 1, prefix[1]);
            insert_shared_prefix(sub_id, base_digit + 2, prefix[2]);
            insert_shared_prefix(sub_id, base_digit + 3, prefix[3]);
        }
    }

    workgroupBarrier();
    let digit_prefix = digit_histogram[chunk_byte];
    let global_prefix = global_histogram[workgroup_id.x >> 8][chunk_byte];
    let histogram_prefix = workgroup_histogram[workgroup_id.x][chunk_byte];
    
    let final_prefix = digit_prefix + global_prefix + histogram_prefix +
        index_shared_prefix(subgroup_id, chunk_byte);
    entity_buffer_1[final_prefix] = entity_vector;
}