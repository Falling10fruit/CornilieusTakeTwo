struct AtomicCount {
    count: atomic<u32>,
    prefix_sum: u32
}
@group(0) @binding(0) var<storage, read_write> byte_count : array<AtomicCount>;

var<workgroup> shared_copy : array<u32, 256>;

@compute @workgroup_size(256) fn sort_entities( //
    @builtin(local_invocation_index) local_invocation_index : u32,
) {
    shared_copy[local_invocation_index] = atomicLoad(&byte_count[local_invocation_index].count);

    workgroupBarrier();
    // Kogge Stone, thanks gemini for teaching me. i still cant read papers. low attention span ahh
    for (var stride : u32 = 1; stride < 256; stride *= 2) {

        var temporary : u32;
        if (local_invocation_index >= stride) {
            temporary = shared_copy[local_invocation_index - stride];
        } workgroupBarrier();
        
        
        if (local_invocation_index >= stride) {
            shared_copy[local_invocation_index] += temporary;
        } workgroupBarrier();
    }

    byte_count[local_invocation_index].prefix_sum = shared_copy[local_invocation_index];
}