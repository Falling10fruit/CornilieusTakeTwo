declare global { interface Window { gpu_sort: {
    workgroup_histogram: GPUBuffer;
    global_histogram: GPUBuffer;
    bind_group_layout: GPUBindGroupLayout;
    bind_group: GPUBindGroup;
} } } export {}
