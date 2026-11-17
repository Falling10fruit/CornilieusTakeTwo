const QUERY_SET_COUNT = 2;

function create_gpu_objects(device:GPUDevice, ctx:GPUCanvasContext) {
    window.compute = {
        timing: create_timing_objects(device),
        debug: create_debug_objects(device),
        minesweeper: create_minesweeper_objects(device)
    }
    
    // so its bind group can use any resource
    window.render = create_render_objects(device, ctx)
}

function create_timing_objects(device:GPUDevice) {
    return {
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

    return {
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

function create_minesweeper_objects(device:GPUDevice) {
    const tiles_buffer = device.createBuffer({
        label: `tiles buffer`,
        size: window.grid.max_height * window.grid.max_width * 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });

    const grid_dimensions_buffer = device.createBuffer({
        label: `grid dimensions buffer`,
        size: 32,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_SRC
    });

    const mouse_pos_buffer = device.createBuffer({
        label: `mouse position buffer`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_SRC
    });

    const bind_group_layout = device.createBindGroupLayout({
        label: `minesweeper bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" } },
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" } },
        ]
    });

    return {
        tiles_buffer,
        grid_dimensions_buffer,
        mouse_pos_buffer,

        bind_group_layout,
        bind_group: device.createBindGroup({
            label: `minesweeper bind group`,
            layout: bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: tiles_buffer } },
                { binding: 1, resource: { buffer: mouse_pos_buffer } },
                { binding: 2, resource: { buffer: mouse_pos_buffer } }
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

    return {
        viewport_buffer,
        frame_buffer,

        bind_group_layout,
        bind_group: device.createBindGroup({
            label: "render buffer bind group",
            layout: bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: viewport_buffer } },
                { binding: 1, resource: { buffer: window.compute.minesweeper.tiles_buffer } },
            ]
        })
    }
}

export { create_gpu_objects }