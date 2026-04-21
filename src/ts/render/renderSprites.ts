let device: GPUDevice;
let vertex_bind_group: GPUBindGroup;
let fragment_bind_group: GPUBindGroup;
let pipeline: GPURenderPipeline;

import { invoke } from "@tauri-apps/api/core";

async function setUpRenderSprites (parameters: { device: GPUDevice}) {
    device = parameters.device;

    const vShaderSource: string = await invoke('get_sprite_vertex_shader');
    const fShaderSource: string = await invoke ('get_sprite_fragment_shader');
    const vShader: GPUShaderModule = device.createShaderModule({ label: `render sprites vertex shader`, code: vShaderSource });
    const fShader: GPUShaderModule = device.createShaderModule({ label: `render sprites fragment shader`, code: fShaderSource });

    
    const vertex_bind_group_layout = device.createBindGroupLayout({
        label: `render sprites vertex bind group layout`,
        entries: [   
            { binding: 0, visibility: GPUShaderStage.VERTEX, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry, // transform camera
            { binding: 1, visibility: GPUShaderStage.VERTEX, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry, // screen resolution
            { binding: 2, visibility: GPUShaderStage.VERTEX, buffer: { type: "read-only-storage" } } as GPUBindGroupLayoutEntry, // current sprite buffer
            { binding: 3, visibility: GPUShaderStage.VERTEX, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry,
            
        ]
    });

    const fragment_bind_group_layout = device.createBindGroupLayout({
        label: `render sprites fragment bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: {} } as GPUBindGroupLayoutEntry, // spritesheet
            { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "non-filtering" }, } as GPUBindGroupLayoutEntry, // sampler for spritesheet
        ]
    })
    
    vertex_bind_group = device.createBindGroup({
        label: `render sprites vertex bind group`,
        layout: vertex_bind_group_layout,
        entries: [
            { binding: 0, resource: { buffer: window.camera.uniformBuffer} } as GPUBindGroupEntry, // camera transform
            { binding: 1, resource: { buffer: window.viewportUniform } } as GPUBindGroupEntry, // viewport resolutoion
            { binding: 2, resource: { buffer: window.spritesBuffer.current } } as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.world.dimensionsUniform } } as GPUBindGroupEntry,
        ]
    });

    fragment_bind_group = device.createBindGroup({
        label: `render sprites fragment bind group`,
        layout: fragment_bind_group_layout,
        entries: [
            { binding: 0, resource: window.spritesheet.texture } as GPUBindGroupEntry,
            { binding: 1, resource: window.spritesheet.sampler } as GPUBindGroupEntry,
        ]
    })
    
    pipeline = await device.createRenderPipelineAsync({
        label: `render sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `render sprites pipeline layout`,
            bindGroupLayouts: [ vertex_bind_group_layout, fragment_bind_group_layout ],
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
    pass.setBindGroup(0, vertex_bind_group);
    pass.setBindGroup(1, fragment_bind_group);
    pass.draw(3, 10);
};

export { setUpRenderSprites, renderSprites }