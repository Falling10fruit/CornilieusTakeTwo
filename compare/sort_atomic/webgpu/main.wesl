enable subgroups;
diagnostic(off, subgroup_uniformity);
// I have a lot of comments just to remind me how stuff I wrote works
// type (2^11 = 2048)           chunk index 2^24         xPos(2^8)    yPos (2 * 16 pixels divided by 2^8)     rotation 2^13 
//  [ 01010101 010 ][ 10101 01010101 01010101 | 010 ][ 10101 010 ]             [ 10101 010 ]             [ 10101 01010101 ] |

@group(0) @binding(0) var<storage, read_write> entity_buffer_0 : array<vec4u>;
@group(0) @binding(1) var<storage, read_write> entity_buffer_1 : array<vec4u>;
// wesl override
const ENTITY_COUNT_LOG2 : u32 = constants::ENTITY_COUNT_LOG2; // only down to 20
const WORKGROUP_HISTOGRAM_LENGTH = (1u << ENTITY_COUNT_LOG2) >> 12;
@group(1) @binding(0) var<storage, read_write> workgroup_histogram : array<array<u32, WORKGROUP_HISTOGRAM_LENGTH>, 256>;
@group(1) @binding(1) var<storage, read_write> digit_histogram : array<u32, 256>;
@group(2) @binding(0) var<storage, read_write> debug_buffer : u32;

@group(3) @binding(0) var<storage, read_write> read_subgroup_size : u32;

override BYTE_SHIFT : u32 = 0; // 0 -> 2

fn get_chunk_from_entity_vector(vector:vec4u) -> u32 {
    if (BYTE_SHIFT == 0u) {
        return ((vector.x & 0x1Fu) << 3) + (vector.y >> 29);
    } else {
        return 0xFFu & (vector.x >> (5 + 8 * BYTE_SHIFT));
    }
}

override IS_CHECKING_SUBGROUP_SIZE : bool = true;
override SUBGROUP_SIZE : u32 = 16u; // or 16
override SUBGROUP_COUNT : u32 = 256u / SUBGROUP_SIZE;

var<workgroup> shared_histogram:array<atomic<u32>, 256>;

// 256, 16
@compute @workgroup_size(256) fn local_accumulation(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_size) subgroup_size : u32,
    @builtin(subgroup_invocation_id) sub_id : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let workgroup_index = workgroup_id.x + workgroup_id.y * 256;
    let local_index = subgroup_id * subgroup_size + sub_id;

    for (var i = 0u; i < 16; i++) {
        let entity_vector = entity_buffer_0[workgroup_index * 256 * 16 + local_index + i * 256];
        let chunk_byte = get_chunk_from_entity_vector(entity_vector);

        atomicAdd(&shared_histogram[chunk_byte], 1u);
        workgroupBarrier();
    }
    
    workgroupBarrier();
    workgroup_histogram[local_index][workgroup_index] = atomicLoad(&shared_histogram[local_index]);
}

var<workgroup> previous_total:u32;
var<workgroup> subgroup_totals:array<u32, SUBGROUP_COUNT>;
// 256
@compute @workgroup_size(256) fn global_accumulation(
    @builtin(workgroup_id) workgroup_id : vec3u, 
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;

    for (var i  = 0u; i < 16; i++) {
        let this_increment:u32 = workgroup_histogram[local_index + i * 256];
        let subgroup_prefix = subgroupExclusiveAdd(this_increment);
        let highest = subgroupMax(subgroup_prefix) + this_increment;
        if (sub_id == subgroup_size - 1) { subgroup_totals[subgroup_id] = highest; }
        workgroupBarrier();

        let workgroup_prefix = subgroupExclusiveAdd(select(0u, subgroup_totals[sub_id], sub_id < SUBGROUP_COUNT));
        let final_prefix = subgroup_prefix + subgroupShuffle(workgroup_prefix, subgroup_id);
        workgroup_histogram[local_index + i * 256] = final_prefix;
        if (local_index == 255) { previous_total = highest + workgroup_prefix; }
    }

    if (local_index == 255) { digit_histogram[workgroup_id.x] = previous_total; }
} 

// one workgroup
@compute @workgroup_size(256) fn digit_prefix(
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;

    let this_increment:u32 = workgroup_histogram[local_index][WORKGROUP_HISTOGRAM_LENGTH - 1];
    let subgroup_prefix = subgroupExclusiveAdd(this_increment);
    if (sub_id == subgroup_size - 1) { subgroup_totals[subgroup_id] = subgroup_prefix + this_increment; }
    workgroupBarrier();

    let workgroup_prefix:u32 = subgroupExclusiveAdd(select(0u, subgroup_totals, sub_id < subgroup_size));
    digit_histogram[local_index] = subgroup_prefix + subgroupShuffle(workgroup_prefix, subgroup_id);
}

// 256 * 256 = 65536  workgroups for 2^24 entities
@compute @workgroup_size(256) fn rescatter(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(subgroup_id) subgroup_id : u32,
    @builtin(subgroup_invocation_id) sub_id : u32,
    @builtin(subgroup_size) subgroup_size : u32
) {
    if (IS_CHECKING_SUBGROUP_SIZE) { read_subgroup_size = subgroup_size; }
    let local_index = subgroup_id * subgroup_size + sub_id;

    let digit_offset = digit_histogram[]
    
    for (var i  = 0u; i < 16; i++) {
        let this_increment:u32 = workgroup_histogram[local_index + i * 256];
        let subgroup_prefix = subgroupExclusiveAdd(this_increment);
        let highest = subgroupMax(subgroup_prefix) + this_increment;
        if (sub_id == subgroup_size - 1) { subgroup_totals[subgroup_id] = highest; }
        workgroupBarrier();

        let workgroup_prefix = subgroupExclusiveAdd(select(0u, subgroup_totals[sub_id], sub_id < SUBGROUP_COUNT));
        let final_prefix = subgroup_prefix + subgroupShuffle(workgroup_prefix, subgroup_id);
        workgroup_histogram[local_index + i * 256] = final_prefix;
        if (local_index == 255) { previous_total = highest + workgroup_prefix; }
    }
}