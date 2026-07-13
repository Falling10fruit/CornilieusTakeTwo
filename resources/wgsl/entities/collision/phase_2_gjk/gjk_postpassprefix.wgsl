struct EntityData {
    gjk_bounds_dictionary_pointer: u32,
    gjk_bounds_count: u32,
    center: vec2f,
    dimensions: vec2f,
    mass: f32,
    default_sprite: u32
}
@group(0) @binding(0) var<storage, read> entity_type_data_buffer : array<EntityData>;
@group(0) @binding(1) var<storage, read> entity_nodes : array<vec2f>;
@group(0) @binding(2) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(3) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(5) var<storage, read_write> entities_buffer_1 : array<vec4u>;
@group(0) @binding(6) var<storage, read_write> entities_buffer_meta : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> debug_buffer : f32; // ##DEBUG_TYPE##=
@group(1) @binding(1) var<storage, read>       cosin_lut : array<vec2f>;
@group(1) @binding(2) var<storage, read_write> hilbert_curve : array<u32>;
@group(1) @binding(3) var<storage, read>       world_data : array<u32>;

// it's postpassprefix because it's my project i can do whatever i want
override ENTITY_COUNT_LOG2 : u32 = 24;
override PREFIX_CHUNK_WIDTH : u32 = 256u >> (24 - ENTITY_COUNT_LOG2);

var<workgroup> shared_local_prefix : array<u32, PREFIX_CHUNK_WIDTH>;
// 2048 workgroups - 2048 chunks
@compute @workgroup_size(PREFIX_CHUNK_WIDTH) fn local_sums(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32,
    @builtin(workgroup_id) workgroup_id : vec3u
) {
    let count = entities_buffer_meta[global_invocation_id.x].x;
    shared_local_prefix[local_id] = count;

    for (var stride : u32 = 1; stride < PREFIX_CHUNK_WIDTH; stride <<= 1) {
        var temp : u32;
        if (local_id >= stride) { temp = shared_local_prefix[local_id - stride]; }
        workgroupBarrier();

        if (local_id >= stride) { shared_local_prefix[local_id] += temp; }
        workgroupBarrier();
    }

    if (local_id == 0) { entities_buffer_meta[workgroup_id.x].y = shared_local_prefix[PREFIX_CHUNK_WIDTH - 1]; }
}

var<workgroup> shared_global_prefix : array<u32, 2048>;

@compute @workgroup_size(1024) fn global_prefix(
    @builtin(local_invocation_index) local_id : u32
) {
    shared_global_prefix[local_id] = entities_buffer_meta[local_id].y;
    shared_global_prefix[local_id + 1024] = entities_buffer_meta[local_id + 1024].y;
    workgroupBarrier();

    for (var stride : u32 = 1; stride < 2048; stride <<= 1) {
        var temp : vec2u;
        for (var i : u32 = 0; i < 2; i++) {
            let index = local_id + i * 1024;
            if (index >= stride) { temp[i] = shared_global_prefix[index - stride]; }
        }
        workgroupBarrier();

        for (var i : u32 = 0; i < 2; i++) {
            let index = local_id + i * 1024;
            if (index >= stride) { shared_global_prefix[index] += temp[i]; }
        }
        workgroupBarrier();
    }

    entities_buffer_meta[local_id * PREFIX_CHUNK_WIDTH].y = shared_global_prefix[local_id];
    entities_buffer_meta[(local_id + 1024) * PREFIX_CHUNK_WIDTH].y = shared_global_prefix[local_id + 1024];

    if (local_id == 0) { entities_buffer_meta[0].z = shared_global_prefix[2047]; }
}

var<workgroup> shared_prefix_sum : array<u32, PREFIX_CHUNK_WIDTH>;
var<private> private_prefix_sum : array<u32, 32>;
// 2048 workgroups
@compute @workgroup_size(PREFIX_CHUNK_WIDTH) fn local_prefix(
    @builtin(workgroup_id) workgroup_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let global_count_offset = select(entities_buffer_meta[(workgroup_id.x - 1) * PREFIX_CHUNK_WIDTH].y, 0, workgroup_id.x == 0);
    shared_prefix_sum[local_id] = entities_buffer_meta[workgroup_id.x * PREFIX_CHUNK_WIDTH + local_id].x;
    workgroupBarrier();
    
    for (var i : u32 = 0; i < PREFIX_CHUNK_WIDTH; i <<= 1) {
        var temp : u32;
        if (local_id >= i) { temp = shared_prefix_sum[local_id - i]; }
        workgroupBarrier();

        if (local_id >= i) { shared_prefix_sum[local_id] += temp; }
        workgroupBarrier();
    }

    let memory_offset = select(shared_prefix_sum[local_id - 1], 0, local_id == 0) + global_count_offset;
    var accumulated_prefix : u32 = 0;
    for (var i : u32 = 0; i < 32; i++) {
        let entity_index = PREFIX_CHUNK_WIDTH * 32 * workgroup_id.x + local_id + i * PREFIX_CHUNK_WIDTH;
        let entity_vector = entities_buffer_1[entity_index];
        let unfinished_flag = entity_vector.w >> 31;

        if (bool(unfinished_flag)) { entities_buffer_meta[memory_offset + accumulated_prefix].w = entity_index; }
    
        accumulated_prefix += unfinished_flag;
    }

}