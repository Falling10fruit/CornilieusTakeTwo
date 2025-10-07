function createBindGroupsAndLayouts(parameters: { device: GPUDevice }) {
    const device = parameters.device;
    createComputeBindGroupsAndLayouts(device);
    createRenderBindGroupsAndLayouts(device);
}

function createComputeBindGroupsAndLayouts(device: GPUDevice) {
    window.bindGroupLayouts.compute.push()
}

function createRenderBindGroupsAndLayouts(device: GPUDevice) {
    window.bindGroupLayouts.render.push(device.createBindGroupLayout({
        label: `camera bind group layout`,
        entries: [    
            { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry,
        ]
    })); if (window.bindGroupLayouts.render[0] == null) return window.fail({ title: `render bind group layout is null`, message: `bind group layout of index 0 is null`});
    window.bindGroups.render.push(device.createBindGroup({
        label: `camera bind group`,
        layout: window.bindGroupLayouts.render[0],
        entries: [
            { binding: 0, resource: { buffer: window.camera.uniformBuffer} } as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.viewportUniform } } as GPUBindGroupEntry,
        ]
    }));
    
    window.bindGroupLayouts.render.push(device.createBindGroupLayout({
        label: `spritesheet bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: {} } as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "non-filtering" }, } as GPUBindGroupLayoutEntry,
        ]
    })); if (window.bindGroupLayouts.render[1] == null) return window.fail({ title: `render bind group layout is null`, message: `bind group layout of index 1 is null`})
    window.bindGroups.render.push(device.createBindGroup({
        label: `spritesheet bind group`,
        layout: window.bindGroupLayouts.render[1],
        entries: [
            { binding: 0, resource: window.spritesheet.texture } as GPUBindGroupEntry,
            { binding: 1, resource: window.spritesheet.sampler } as GPUBindGroupEntry,
        ]
    }));
    
    window.bindGroupLayouts.render.push(device.createBindGroupLayout({
        label: `world data bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" } } as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry
        ]
    })); if (window.bindGroupLayouts.render[2] == null) return window.fail({ title: `render bind group layout is null`, message: `bind group layout of index 2 is null`})
    window.bindGroups.render.push(device.createBindGroup({
        label: `world data bind group`,
        layout: window.bindGroupLayouts.render[2],
        entries: [
            { binding: 0, resource: { buffer: window.world.storageBuffer } } as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.world.dimensionsUniform } } as GPUBindGroupEntry
        ]
    }));
}

export { createBindGroupsAndLayouts }