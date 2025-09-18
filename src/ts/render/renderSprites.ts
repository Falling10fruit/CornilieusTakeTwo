let device: GPUDevice;
let bindGroupLayout: GPUBindGroupLayout;
let pipeline: GPURenderPipeline;
let bindGroup: GPUBindGroup;

import { invoke } from "@tauri-apps/api/core";

async function setUpRenderSprites (parameters: { device: GPUDevice}) {
    device = parameters.device;

    const vShaderSource: string = await invoke('get_sprite_vertex_shader');
    const fShaderSource: string = await invoke ('get_sprite_fragment_shader');
    const vShader: GPUShaderModule = device.createShaderModule({ label: `render sprites vertex shader`, code: vShaderSource });
    const fShader: GPUShaderModule = device.createShaderModule({ label: `render sprites fragment shader`, code: fShaderSource });

    bindGroupLayout = device.createBindGroupLayout({
        label: `render sprites bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.VERTEX,   buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.VERTEX,   buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry,
            { binding: 2, visibility: GPUShaderStage.FRAGMENT, externalTexture: {} } as GPUBindGroupLayoutEntry,
            { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "non-filtering" } } as GPUBindGroupLayoutEntry,
            { binding: 4, visibility: GPUShaderStage.VERTEX,   buffer: { type: "storage" } } as GPUBindGroupLayoutEntry
        ]
    });
    
    pipeline = await device.createRenderPipelineAsync({
        label: `render sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `render sprites pipeline layout`,
            bindGroupLayouts: [bindGroupLayout],
        }),
        vertex: {
            module: vShader,
            entryPoint: "vertexShader",
        },
        fragment: {
            module: fShader,
            entryPoint: "fragmentShader",
            targets: [{
                format: navigator.gpu.getPreferredCanvasFormat(),
            }],
        },
    });

    bindGroup = await device.createBindGroup({
        label: `render sprites bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.camera.uniformBuffer} } as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.viewportUniform } } as GPUBindGroupEntry,
            { binding: 2, resource: window.spritesheet.texture } as GPUBindGroupEntry,
            { binding: 3, resource: window.spritesheet.sampler } as GPUBindGroupEntry,
            { binding: 4, resource: { buffer: window.spritesBuffer } } as GPUBindGroupEntry
        ]
    });
}

function renderSprites (pass: GPURenderPassEncoder) {
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(3);
};

export { setUpRenderSprites, renderSprites }