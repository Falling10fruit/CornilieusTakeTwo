struct AtomicCount {
    count: atomic<u32>,
    prefix_sum: u32
}
@group(1) @binding(0) var<storage, read_write> byte_count : array<AtomicCount>;

var<workgroup> shared_copy : array<u32, 16>;

@compute @workgroup_size(16) fn chunk_prefix( //
    @builtin(local_invocation_index) local_invocation_index : u32,
) {
    shared_copy[local_invocation_index] = atomicLoad(&byte_count[local_invocation_index].count);

    workgroupBarrier();
    for (var stride : u32 = 1; stride < 16; stride *= 2) {

        var temporary : u32;
        if (local_invocation_index >= stride) {
            temporary = shared_copy[local_invocation_index - stride];
        } workgroupBarrier();
        
        
        if (local_invocation_index >= stride) {
            shared_copy[local_invocation_index] += temporary;
        } workgroupBarrier();
    }

    byte_count[0].prefix_sum = 0;
    if (local_invocation_index != 0) {
        byte_count[local_invocation_index].prefix_sum = shared_copy[local_invocation_index - 1];
    }
}