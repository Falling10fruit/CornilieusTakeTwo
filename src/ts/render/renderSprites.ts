let device: GPUDevice;
let pipeline: GPURenderPipeline;

import { invoke } from "@tauri-apps/api/core";

async function setUpRenderSprites (parameters: { device: GPUDevice}) {
    device = parameters.device;

    const vShaderSource: string = await invoke('get_sprite_vertex_shader');
    const fShaderSource: string = await invoke ('get_sprite_fragment_shader');
    const vShader: GPUShaderModule = device.createShaderModule({ label: `render sprites vertex shader`, code: vShaderSource });
    const fShader: GPUShaderModule = device.createShaderModule({ label: `render sprites fragment shader`, code: fShaderSource });

    
    pipeline = await device.createRenderPipelineAsync({
        label: `render sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `render sprites pipeline layout`,
            bindGroupLayouts: [
                window.bindGroupLayouts.render[0],
                window.bindGroupLayouts.render[1],
                window.bindGroupLayouts.render[3],
            ], // I need camera spritesheet and  spriteBuffer
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
    pass.draw(3, 1);
};

export { setUpRenderSprites, renderSprites }