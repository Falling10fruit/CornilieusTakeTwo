enable subgroups;
requires subgroup_id;
// I have a lot of comments just to remind me how stuff I wrote works
// type (2^11 = 2048)           chunk index 2^24         xPos(2^8)    yPos (2 * 16 pixels divided by 2^8)     rotation 2^13 
//  [ 01010101 010 ][ 10101 01010101 01010101 | 010 ][ 10101 010 ]             [ 10101 010 ]             [ 10101 01010101 ] |

@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;
// wesl override
const ENTITY_COUNT_LOG2 : u32 = constants::ENTITY_COUNT_LOG2; // only down to 20
const WORKGROUP_HISTOGRAM_LENGTH = (1u << ENTITY_COUNT_LOG2) >> 8u;
const GLOBAL_HISTOGRAM_LENGTH = WORKGROUP_HISTOGRAM_LENGTH >> 8u;
@group(1) @binding(0) var<storage, read_write> workgroup_histogram : array<array<u32, WORKGROUP_HISTOGRAM_LENGTH>, 256>;
@group(1) @binding(1) var<storage, read_write> global_histogram : array<array<u32, GLOBAL_HISTOGRAM_LENGTH>, 256>;
// @group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

@group(3) @binding(0) var<storage, read_write> read_subgroup_size : u32;

override BYTE_SHIFT : u32 = 0; // 0 -> 2

override IS_CHECKING_SUBGROUP_SIZE : bool = true;
override SUBGROUP_SIZE : u32 = 32u; // or 16
override SUBGROUP_COUNT : u32 = 256u / SUBGROUP_SIZE;
var<workgroup> shared_prefix_16 : array<array<vec4u, 16>, SUBGROUP_COUNT>; // overflow means that all but (23 oct 2026 what the hell are you trying to say yoga)

fn get_chunk_from_entity_vector(vector:vec4u) -> u32 {
    if (BYTE_SHIFT == 0u) {
        return ((vector.x & 0x1Fu) << 3) + (vector.y >> 29);
    } else {
        return 0xFFu & (vector.x >> (5 + 8 * BYTE_SHIFT));
    }
}

fn get_chunk_byte_into_shared_prefix(workgroup_index: u32, local_index: u32, subgroup_id: u32){
    let entity_vector = entity_buffer_0[workgroup_index * 256 + local_index];
    let chunk_byte = get_chunk_from_entity_vector(entity_vector);

    var havent_finished = true;
    while (subgroupAny(havent_finished)) {
        let is_active = havent_finished && (chunk_byte == subgroupBroadcastFirst(chunk_byte));
        let total = subgroupAdd(select(0u, 1u, is_active));
        if (subgroupElect()) { shared_prefix_16[subgroup_id][chunk_byte >> 4][(chunk_byte >> 2) & 3u] += total << (8 * (chunk_byte & 3u)); }
        havent_finished = havent_finished && !is_active;
        workgroupBarrier();
    }
}

// 256 * 256 = 65536  workgroups for 2^24 entities
@compute @workgroup_size(256) fn local_accumulation(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_index : u32,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    const subgroup_count = 256u / subgroup_size;
    
    let workgroup_index = workgroup_id.x + workgroup_id.y * 256;
    get_chunk_byte_into_shared_prefix(workgroup_index, local_index, subgroup_id);
    // we only subgroupAdd once here because get_chunk_byte_into_shared_prefix already subgroupAdd
    let this_increment: vec4u = select(vec4u(0, 0, 0, 0), shared_prefix_16[sub_id][subgroup_id], sub_id < subgroup_count);
    var total = subgroupAdd(this_increment);
    
    let vector_index = (sub_id >> 2) & 3u;
    let integer_shift = 8 * (sub_id & 3u);
    var final_value = (total[vector_index] >> integer_shift) & 0xFFu;
    
    let is_final_zero = final_value == 0u;
    let is_this_zero = ((this_increment[vector_index] >> integer_shift) & 0xFFu) == 0u;
    let is_overflow = is_final_zero && !is_this_zero; 
    
    if (subgroupAny(is_overflow)) { // the thread with the overflow has to share the same vec4u aka be in the same subgroup
        workgroup_histogram[sub_id + subgroup_id * subgroup_size][workgroup_index] = subgroupShuffleDown(final_value, 1u) * 256;
    } else {
        workgroup_histogram[sub_id + subgroup_id * subgroup_size][workgroup_index] = final_value;
    }
}

@compute @workgroup_size(256) fn local_accumulation_8(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_index : u32,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32
) {
    let workgroup_index = workgroup_id.x + workgroup_id.y * 256;
    get_chunk_byte_into_shared_prefix(workgroup_index, local_index, subgroup_id);

    let vec4u_index = subgroup_id & 0xFu;
    let subgroup_shift = subgroup_id >> 4;
    let this_shift = subgroup_shift * 16 + sub_id * 2;
    let this_increment: vec4u = shared_prefix_16[this_shift][vec4u_index] + shared_prefix_16[this_shift + 1][vec4u_index];
    let total = subgroupAdd(this_increment);

    workgroupBarrier();
    if (subgroupElect()) { shared_prefix_16[subgroup_shift][vec4u_index] = total; }
    workgroupBarrier();

    var total: vec4u;
    if (subgroup_id < 16) {
        total = subgroupAdd(select(0u, shared_prefix_16[sub_id][subgroup_id], sub_id < 2));
        if (subgroupElect()) { shared_prefix_16[0][subgroup_id] = total; }
    } workgroupBarrier();
    if (subgroup_id >= 16) { total = shared_prefix_16[0][vec4u_index]; }

    let total_index = (subgroup_shift << 1) + (sub_id >> 2);
    let integer_shift = 8 * (sub_id & 3u);
    let final_value = (total[total_index] >> integer_shift) & 0xFFu;
    let this_value = (this_increment[total_index] >> integer_shift) & 0xFFu;

    let is_final_zero = final_value == 0u;
    let is_this_zero = this_value == 0u;
    let is_overflow = is_final_zero && !is_this_zero;

    if (subgroupAny(is_overflow)) {
        workgroup_histogram[(vec4u_index << 4) + (subgroup_shift << 3) + sub_id][workgroup_index] = subgroupShuffleDown(final_value, 1u) * 256;
    } else {
        workgroup_histogram[(vec4u_index << 4) + (subgroup_shift << 3) + sub_id][workgroup_index] = final_value;
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
        return;
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

override SHARED_PREFIX_4_GLOBAL_PREFIX_LENGTH: u32 = 256u / SUBGROUP_SIZE;
var<workgroup> shared_prefix_4_global_prefix : array<u32, SHARED_PREFIX_4_GLOBAL_PREFIX_LENGTH>;
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

    var this_increment = global_histogram[workgroup_id.y][local_index];
    var this_prefix = subgroupExclusiveAdd(this_increment);
    var subgroup_max = subgroupMax(this_prefix + this_increment);
    if (subgroupElect()) { shared_prefix_4_global_prefix[subgroup_id] = subgroup_max; }

    var subgroup_prefix = subgroupExclusiveAdd(select(0u, shared_prefix_4_global_prefix[sub_id], sub_id < SHARED_PREFIX_4_GLOBAL_PREFIX_LENGTH));
    global_histogram[workgroup_id.y][local_index] = subgroup_prefix + this_increment;
}

var<workgroup> digit_offset: atomic<u32>;

// 256 * 256 = 65536  workgroups for 2^24 entities
@compute @workgroup_size(1, 256) fn rescatter(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_index : u32,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;
    
    let workgroup_index = workgroup_id.x + workgroup_id.y * 256;
    let entity_vector = entity_buffer_0[workgroup_index * 256 + local_index];
    let chunk_byte = get_chunk_from_entity_vector(entity_vector);

    var not_done = true;
    while (subgroupAll(not_done)) {
        let this_prefix = subgroupExclusiveAdd(select(0u, 1u, subgroupBroadcastFirst(chunk_byte) == chunk_byte));
        let this_max = subgroupMax(this_prefix) + 1u;
        if (subgroupElect()) { 
            shared_prefix_16[subgroup_id][chunk_byte >> 4][(chunk_byte >> 2) & 3u] += this_max << (8 * (chunk_byte & 3u)); 
        }
    }

    let global_prefix = global_histogram[workgroup_id.x >> 8];
    let histogram_prefix = workgroup_histogram[workgroup_id.x & 0xFu];
    let prefix = subgroupExclusiveAdd(shared_prefix_16[local_index & 0xFu][(local_index >> 6) & 3u])[(local_index >> 4) & 3u]; // idk im larping
    let total_prefix = global_prefix + histogram_prefix + prefix;

}