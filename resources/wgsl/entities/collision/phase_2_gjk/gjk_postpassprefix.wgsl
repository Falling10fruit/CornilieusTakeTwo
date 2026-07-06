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
@group(0) @binding(1) var<storage, read_write> entities_indicies : array<u32>;
@group(0) @binding(2) var<storage, read_write> chunk_indicies : array<u32>;
@group(0) @binding(3) var<storage, read_write> entities_buffer_0 : array<vec4u>;
@group(0) @binding(4) var<storage, read_write> entities_buffer_1 : array<vec4u>;
@group(0) @binding(6) var<storage, read_write> entities_buffer_meta : array<vec4u>;

@group(1) @binding(0) var<storage, read_write> debug_buffer : f32; // ##DEBUG_TYPE##=
@group(1) @binding(1) var<storage, read>       cosin_lut : array<vec2f>;
@group(1) @binding(2) var<storage, read_write> hilbert_curve : array<u32>;
@group(1) @binding(3) var<storage, read>       world_data : array<u32>;

// it's postpassprefix because it's my project i can do whatever i want
override HALF_PHASE : u32 = 0;
override ENTITY_COUNT_LOG2 : u32 = 24;
override PREFIX_CHUNK_WIDTH : u32 = 512u >> (24 - ENTITY_COUNT_LOG2);

var<workgroup> shared_local_prefix : array<u32, PREFIX_CHUNK_WIDTH>;
// 1024 workgroups - 1024 chunks
@compute @workgroup_size(PREFIX_CHUNK_WIDTH) fn local_sums(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32,
    @builtin(workgroup_id) workgroup_id : vec3u
) {
    let count = entities_buffer_meta[global_invocation_id.x].x;
    shared_local_prefix[local_id] = count;

    // ironically we only want the last element this time
    for (var stride : u32 = 1; stride <= PREFIX_CHUNK_WIDTH; stride <<= 1) {
        var temp : u32;
        if (local_id >= stride) { temp = shared_local_prefix[local_id - stride]; }
        workgroupBarrier();

        if (local_id >= stride) { shared_local_prefix[local_id] += temp; }
        workgroupBarrier();
    } workgroupBarrier();

    if (local_id == 0) { entities_buffer_meta[workgroup_id.x].y = shared_local_prefix[PREFIX_CHUNK_WIDTH - 1]; }
}

var<workgroup> shared_global_prefix : array<u32, 1024>;

@compute @workgroup_size(1024) fn global_prefix(
    @builtin(local_invocation_index) local_id : u32
) {
    shared_global_prefix[local_id] = entities_buffer_meta[local_id].y;
    workgroupBarrier();

    for (var stride : u32 = 1; stride < 1024; stride <<= 1) {
        if (local_id >= stride)
    }
}