struct EntityData {
    gjk_bounds_dictionary_pointer: u32,
    gjk_bounds_count: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(0) @binding(0) var<storage, read> entity_type_data : array<EntityData>;
@group(0) @binding(1) var<storage, read> entity_nodes : array<vec2f>;
@group(0) @binding(1) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<vec4u>;
@group(0) @binding(6) var<storage, read_write> entities_buffer_meta : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> debug_buffer : f32; // ##DEBUG_TYPE##=
@group(1) @binding(1) var<storage, read>       cosin_lut : array<vec2f>;
@group(1) @binding(2) var<storage, read_write> hilbert_curve : array<u32>;
@group(1) @binding(3) var<storage, read>       world_data : array<u32>;

override HALF_PHASE : u32; // 0 for the first half
override ENTITY_COUNT_LOG2 : u32 = 24; // oh btw it can only go down to 21
override PREFIX_CHUNK_WIDTH : u32 = 4096u >> (24 - ENTITY_COUNT_LOG2);

// x - the individual total boundaries of the one vector
// y - chunk sum -> prefix

// 512 * 512 = 262,144 total workgroups please (for a total of 2^23 threads)
// the y direction will be used to scale the algorithm
@comgpute @workroup_size(32) fn individual_boundaries_count(
    @builtin(global_invocation_id) global_invocation_id : vec3u
) {
    let global_index = global_invocation_id.x + global_invocation_id.y * 512 * 32;
    let index_offset = arrayLength(&entities_buffer_meta) / 2;

    let data_vector = entities_buffer_meta[global_index];
    let gjk_counts = ((data_vector >> vec4u(24, 24, 24, 24)) & vec4u(0xFu, 0xFu, 0xFu, 0xFu));

    entities_buffer_meta[index_offset + global_index] = vec4u(
        gjk_counts.x + gjk_counts.y + gjk_counts.z + gjk_counts.w + (data_vector.x >> 28),
        0, 0, 0
    );
}

var<workgroup> local_total : atomic<u32>;
// 2048 workgroups for each chunk
@compute @workgroup_size(256) fn local_sums(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let index_offset = arrayLength(&entities_buffer_meta) / 2;

    let global_offset = workgroup_id.x * PREFIX_CHUNK_WIDTH;
    let no_of_iterations = 16u >> (24 - ENTITY_COUNT_LOG2); 
    for (var i : u32 = 0; i < no_of_iterations; i++) {
        let local_index = i * 256;
        let data = entities_buffer_meta[index_offset + local_index + global_offset];
        atomicAdd(&local_total, data.x);
    }

    workgroupBarrier();

    if (local_id == 0) { entities_buffer_meta[index_offset + workgroup_id.x].y = atomicLoad(&local_total); }
}

var<workgroup> shared_array : array<u32, 2048>;
// 1 workgroup, btw NO NUMBERS CHANGE BECAUSE THERE IS ALWAYS THE SAME NUMBER OF CHUNK OKK? pls remember
@compute @workgroup_size(256) fn global_prefix(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let index_offset = arrayLength(&entities_buffer_meta) / 2;

    for (var i : u32 = 0; i < 8; i++) {
        let index = local_id + i * 256;
        shared_array[index] = entities_buffer_meta[index_offset + index].y;
    } workgroupBarrier();

    for (var stride : u32 = 1; stride < 2048; stride <<= 1) {
        var temp : u32;
        for (var i : u32 = 0; i < 8; i++) {
            let index = local_id + i * 256;
            if (index > stride) { temp = shared_array[index - stride]; }
        } workgroupBarrier();

        for (var i : u32 = 0; i < 8; i++) {
            let index = local_id + i * 256;
            if (index > stride) { temp = shared_array[index - stride];}
        } workgroupBarrier();

    } workgroupBarrier();

    entities_buffer_meta[0].y = 0;
    for (var i : u32 = 0; i < 8; i++) {
        let index = local_id + i * 256;
        entities_buffer_meta[index_offset + index + 1].y = shared_array[index];
    }
}

var<workgroup> global_offset : u32;
var<workgroup> local_array : array<u32, 128>;
var<private> private_array : array<u32, 32>;
var<private> accumulated_sum : u32 = 0;

@compute @workgroup_size(128) fn local_prefix(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let index_offset = arrayLength(&entities_buffer_meta) / 2;

    for (var i : u32 = 0; i < 32; i++) {
        let global_index = global_invocation_id.x + i;

        let data = entities_buffer_meta[index_offset + global_index];
        if (local_id == 0 && i == 0) { global_offset = data.w; }
        
        accumulated_sum += data.x;
        private_array[i] += accumulated_sum;
    }

    local_array[local_id] = accumulated_sum;
    workgroupBarrier();

    for (var stride : u32 = 1; stride < 128; stride <<= 1) {
        var temp : u32;
        if (local_id > stride) { temp = local_array[local_id]; }
        workgroupBarrier();

        if (local_id > stride) { local_array[local_id] = temp; }
        workgroupBarrier();
    } workgroupBarrier();

    let local_offset = select(0, local_array[local_id - 1], local_id == 0);
    let first_index = index_offset + global_invocation_id.x * 8192 + local_id * 32;
    entities_buffer_meta[first_index].y = local_offset + global_offset;
    for (var i : u32 = 1; i < 32; i++) {
        let index = index_offset + global_invocation_id.x * 8192 + local_id * 32 + i;
        entities_buffer_meta[index].y = private_array[i] + local_offset + global_offset;
    }
}