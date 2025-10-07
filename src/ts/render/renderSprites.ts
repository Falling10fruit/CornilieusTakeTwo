let device: GPUDevice;
let bindGroup: GPUBindGroup;
let pipeline: GPURenderPipeline;

import { invoke } from "@tauri-apps/api/core";

async function setUpRenderSprites (parameters: { device: GPUDevice}) {
    device = parameters.device;

    const vShaderSource: string = await invoke('get_sprite_vertex_shader');
    const fShaderSource: string = await invoke ('get_sprite_fragment_shader');
    const vShader: GPUShaderModule = device.createShaderModule({ label: `render sprites vertex shader`, code: vShaderSource });
    const fShader: GPUShaderModule = device.createShaderModule({ label: `render sprites fragment shader`, code: fShaderSource });

    
    const bindGroupLayout = device.createBindGroupLayout({
        label: `render sprites bind group layout`,
        entries: [    
            { binding: 0, visibility: GPUShaderStage.VERTEX, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry, // transform camera
            { binding: 1, visibility: GPUShaderStage.VERTEX, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry, // screen resolution
            { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: {} } as GPUBindGroupLayoutEntry, // spritesheet
            { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "non-filtering" }, } as GPUBindGroupLayoutEntry, // sampler for spritesheet
            { binding: 4, visibility: GPUShaderStage.VERTEX, buffer: { type: "read-only-storage" } } as GPUBindGroupLayoutEntry, // current sprite buffer
        ]
    });
    
    bindGroup = device.createBindGroup({
        label: `render sprites bind group`,
        layout: bindGroupLayout,
        entries: [
            { binding: 0, resource: { buffer: window.camera.uniformBuffer} } as GPUBindGroupEntry, // camera transform
            { binding: 1, resource: { buffer: window.viewportUniform } } as GPUBindGroupEntry, // viewport resolutoion
            { binding: 2, resource: window.spritesheet.texture } as GPUBindGroupEntry,
            { binding: 3, resource: window.spritesheet.sampler } as GPUBindGroupEntry,
            { binding: 4, resource: { buffer: window.spritesBuffer.current } } as GPUBindGroupEntry,
        ]
    });
    
    pipeline = await device.createRenderPipelineAsync({
        label: `render sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `render sprites pipeline layout`,
            bindGroupLayouts: [ bindGroupLayout ],
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
                blend: {
                    color: {
                        srcFactor: 'one',
                        dstFactor: 'one-minus-src-alpha'
                    },
                    
                    alpha: {
                        srcFactor: 'one',
                        dstFactor: 'one-minus-src-alpha'
                    },
                },
            }],
        },
    });
}

function renderSprites (pass: GPURenderPassEncoder) {
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(3, 1);
};

export { setUpRenderSprites, renderSprites }