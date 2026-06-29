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

@compute @workgroup_size(32) fn individual_boundaries_count(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let data_vector = entities_buffer_meta[global_invocation_id.x];
    let gjk_counts = data_vector >> vec4u(24, 24, 24, 24);

    let index_offset = arrayLength(&entities_buffer_meta) / 2;
    entities_buffer_meta[global_invocation_id.x + index_offset] = vec4u(
        gjk_counts.x + gjk_counts.y + gjk_counts.z + gjk_counts.w,
        select(
            entities_buffer_meta[global_invocation_id.x - 1].x,
            data_vector.x,
            (global_invocation_id.x & 1u) == 0
        ) & 0xFFFFFFu, 0, 0
    );
}

var<workgroup> local_total : atomic<u32>;

@compute @workgroup_size(256) fn local_sums(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    let global_offset = global_invocation_id.x * 8192;
    for (var i : u32 = 0; i < 32; i++) {
        let local_index = i * 256;
        let data = entities_buffer_1[local_index + global_offset];
        atomicAdd(&local_total, data.x);
    }

    workgroupBarrier();

    if (local_id == 255) { entities_buffer_1[global_invocation_id.x].w = local_total; }
}

var<workgroup> shared_array : array<u32, 4096>;

@compute @workgroup_size(512) fn global_prefix(
    @builtin(global_invocation_id) global_invocation_id : vec3u,
    @builtin(local_invocation_index) local_id : u32
) {
    for (var i : u32 = 0; i < 8; i++) {
        let index = local_id + i * 512;
        shared_array[index] = entities_buffer_1[index].w;
    } workgroupBarrier();

    for (var stride : u32 = 1; stride < 2048; stride <<= 1) {
        var temp : u32;
        for (var i : u32 = 0; i < 8; i++) {
            let index = local_id + i * 512;
            if (index > stride) { temp = shared_array[index - stride]; }
        } workgroupBarrier();

        for (var i : u32 = 0; i < 8; i++) {
            let index = local_id + i * 512;
            if (index > stride) { temp = shared_array[index - stride];}
        } workgroupBarrier();

    } workgroupBarrier();

    for (var i : u32 = 0; i < 8; i++) {
        let index = local_id + i * 512;

        if (index != 0) {
            entities_buffer_1[(index - 1) * 8192 + 1].w = shared_array[index - 1];
        }
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
    for (var i : u32 = 0; i < 32; i++) {
        let global_index = global_invocation_id.x + i;

        let data = entities_buffer_1[global_index];
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
    entities_buffer_1[global_invocation_id.x * 8192 + local_id * 32].y = local_offset + global_offset;
    for (var i : u32 = 1; i < 32; i++) {
        entities_buffer_1[global_invocation_id.x * 8192 + local_id * 32 + i].y = private_array[i] + local_offset + global_offset;
    }
}