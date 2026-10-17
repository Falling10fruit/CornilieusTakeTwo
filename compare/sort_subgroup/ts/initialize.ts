import { ENTITY_COUNT_LOG2 } from "..";

const QUERY_SET_COUNT = 2;

function create_webgpu_objects(device:GPUDevice, ctx:GPUCanvasContext) {
    const bind_group_layout = device.createBindGroupLayout({
        label: "subgroup test bind group layout",
        entries: [{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } }]
    });

    const entity_buffer_0 = device.createBuffer({
            label: `entity buffer 0`,
            size: 4 * 4 * 2**ENTITY_COUNT_LOG2,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const entity_buffer_1 =  device.createBuffer({
        label: `entity buffer 0`,
        size: 4 * 4 * 2**ENTITY_COUNT_LOG2,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const entity_bind_group_layout = device.createBindGroupLayout({
        label: `entity bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
        ]
    });
    
    window.gpu_main = {
        timing: {
            query_set: device.createQuerySet({
                type: "timestamp",
                count: QUERY_SET_COUNT
            }),
            resolve_buffer: device.createBuffer({
                label: " resolve buffer",
                size: QUERY_SET_COUNT * 8,
                usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC
            }),
            mapped_timed_buffers: [
                device.createBuffer({
                    label: "query result buffer",
                    size: QUERY_SET_COUNT * 8,
                    usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
                }),
                device.createBuffer({
                    label: "query result buffer",
                    size: QUERY_SET_COUNT * 8,
                    usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
                }),
                device.createBuffer({
                    label: "query result buffer",
                    size: QUERY_SET_COUNT * 8,
                    usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
                }),
            ]
        },

        render: {
            viewport_buffer: device.createBuffer({
                label: "viewport buffer",
                size: 2 * 4,
                usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
            }),
            frame_buffer: device.createBuffer({
                label: "frame buffer",
                size: 4 * ctx.canvas.width * ctx.canvas.height,
                usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
            }),
            bind_group_layout: device.createBindGroupLayout({
                label: "render buffer bind group layout",
                entries: [
                    { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
                    { binding: 1, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "storage" } },
                ]
            })
        },

        subgroup_test: {
            bind_group_layout,
            list: Array.from({ length: 5 }, (_, i) => {
                const buffer = device.createBuffer({
                    label: `subgroup test buffer no. ${i}`,
                    size: 4,
                    usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC | GPUBufferUsage.STORAGE
                });
                return {
                    buffer: buffer,
                    bind_group: device.createBindGroup({
                        label: `subgroup test bind group no. ${i}`,
                        layout: bind_group_layout,
                        entries: [{ binding: 0, resource: { buffer: buffer } }]
                    })
                }
            })
        },

        debug: {
            gpu_buffer: device.createBuffer({
                label: "gpu debug buffer",
                size: 4,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
            }),
            gpu_bind_group_layout: device.createBindGroupLayout({
                label: "gpu debug buffer bind group layout",
                entries: [ { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } }]
            }),
            buffer: device.createBuffer({
                label: "debug buffer",
                size: 4,
                usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
            })
        },
        
        entity_buffer_0,
        entity_buffer_1,
        entity_bind_group_layout,
        entity_bind_group: device.createBindGroup({
            label: "entity_bind_group",
            layout: entity_bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: entity_buffer_0 } },
                { binding: 0, resource: { buffer: entity_buffer_1 } },
            ]
        })      
    }

    const workgroup_histogram =  device.createBuffer({
        label: `digital prefix buffer`,
        size: 4 * 256 * 65536 >> (24 - ENTITY_COUNT_LOG2),
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const global_histogram = device.createBuffer({
        label: `global prefix buffer`,
        size: 4 * 256 * 256,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    const sort_bind_group_layout = device.createBindGroupLayout({
        label: "sort bind group layoute",
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } }
        ]
    }) 

    window.gpu_sort = {
        workgroup_histogram,
        global_histogram,
        bind_group_layout,
        bind_group: device.createBindGroup({
            label: "sort bind group",
            layout: sort_bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: workgroup_histogram } },
                { binding: 1, resource: { buffer: global_histogram } },
            ]
        })
    }
}

export { create_webgpu_objects }