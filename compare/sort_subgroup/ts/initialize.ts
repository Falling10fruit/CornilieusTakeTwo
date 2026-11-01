import { ENTITY_COUNT_LOG2 } from "./compute_pipelines";

const QUERY_SET_COUNT = 2;

function create_gpu_objects(device:GPUDevice, ctx:GPUCanvasContext) {
    window.gpu = {};

    create_timing_objects(device);
    create_debug_objects(device);
    create_subgroup_objects(device);
    create_entity_objects(device);
    create_sort_objects(device);

    // so its bind group 
    create_render_objects(device, ctx);
}

function create_timing_objects(device:GPUDevice) {
    window.gpu.timing = {
        query_set: device.createQuerySet({
            type: "timestamp",
            count: QUERY_SET_COUNT
        }),
        resolve_buffer: device.createBuffer({
            label: " resolve buffer",
            size: QUERY_SET_COUNT * 8,
            usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC
        }),
        mapped_timed_buffers: Array.from({length:3}, () => device.createBuffer({
            label: "query result buffer",
            size: QUERY_SET_COUNT * 8,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
        }))
    }
}

function create_debug_objects(device:GPUDevice) {
    const copied_buffer = device.createBuffer({
        label: "gpu debug buffer",
        size: 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const bind_group_layout = device.createBindGroupLayout({
        label: "gpu debug buffer bind group layout",
        entries: [ { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } }]
    })

    window.gpu.debug = {
        copied_buffer,
        bind_group_layout,
        bind_group: device.createBindGroup({
            label: "gpu debug buffer bind group",
            layout: bind_group_layout,
            entries: [{ binding: 0, resource: { buffer: copied_buffer } }]
        }),

        buffer: device.createBuffer({
            label: "debug buffer",
            size: 4,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
        })
    }
}

function create_subgroup_objects(device:GPUDevice) {
    const bind_group_layout = device.createBindGroupLayout({
        label: "subgroup test bind group layout",
        entries: [{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } }]
    });

    window.gpu.subgroup_test = {
        bind_group_layout,
        list: Array.from({ length: 5 }, (_, i) => {
            const copied_buffer = device.createBuffer({
                label: `subgroup test buffer no. ${i}`,
                size: 4,
                usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC | GPUBufferUsage.STORAGE
            });
            const pasted_buffer = device.createBuffer({
                label: `subgroup test buffer no. ${i}`,
                size: 4,
                usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
            });

            return {
                copied_buffer,
                pasted_buffer,
                bind_group: device.createBindGroup({
                    label: `subgroup test bind group no. ${i}`,
                    layout: bind_group_layout,
                    entries: [{ binding: 0, resource: { buffer: copied_buffer } }]
                })
            }
        })
    }
}
        

function create_entity_objects(device:GPUDevice) {
    const buffer_0 = device.createBuffer({
            label: `entity buffer 0`,
            size: 4 * 4 * 2**ENTITY_COUNT_LOG2,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const buffer_1 =  device.createBuffer({
        label: `entity buffer 0`,
        size: 4 * 4 * 2**ENTITY_COUNT_LOG2,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const bind_group_layout = device.createBindGroupLayout({
        label: `entity bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
        ]
    });

    window.gpu.entity = {
        buffer_0,
        buffer_1,
        bind_group_layout,
        bind_group: device.createBindGroup({
            label: "bind_group",
            layout: bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: buffer_0 } },
                { binding: 0, resource: { buffer: buffer_1 } },
            ]
        })
    }
}

function create_sort_objects(device:GPUDevice) {
    const workgroup_histogram =  device.createBuffer({
        label: `digital prefix buffer`,
        size: 4 * 256 * 65536 >> (24 - ENTITY_COUNT_LOG2),
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const global_histogram = device.createBuffer({
        label: `global prefix buffer`,
        size: 4 * 256 * 256 >> (24 - ENTITY_COUNT_LOG2),
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const digit_histogram = device.createBuffer({
        label: `data prefix buffer`,
        size: 4 * 256,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    })
    const bind_group_layout = device.createBindGroupLayout({
        label: "sort bind group layoute",
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } }
        ]
    }) 

    window.gpu.sort = {
        workgroup_histogram,
        global_histogram,
        digit_histogram,
        
        bind_group_layout,
        bind_group: device.createBindGroup({
            label: "sort bind group",
            layout: bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: workgroup_histogram } },
                { binding: 1, resource: { buffer: global_histogram } },
                { binding: 2, resource: { buffer: digit_histogram } }
            ]
        })
    }
}

function create_render_objects(device:GPUDevice, ctx:GPUCanvasContext) {
    const viewport_buffer = device.createBuffer({
        label: "viewport buffer",
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
    const frame_buffer = device.createBuffer({
        label: "frame buffer",
        size: 4 * ctx.canvas.width * ctx.canvas.height,
        usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
    });

    const bind_group_layout = device.createBindGroupLayout({
        label: "render buffer bind group layout",
        entries: [
            { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
            { binding: 1, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "storage" } },
        ]
    });

    window.gpu.render = {
        viewport_buffer,
        frame_buffer,

        bind_group_layout,
        bind_group: device.createBindGroup({
            label: "render buffer bind group",
            layout: bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: viewport_buffer } },
                { binding: 1, resource: { buffer: window.gpu.sort.workgroup_histogram } },
            ]
        })
    }
}

export { create_gpu_objects }