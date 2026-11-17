import wgsl from "../webgpu/render_buffer.wgsl?raw"

async function return_render_pipeline(device:GPUDevice) {
    const shader = device.createShaderModule({
        label: "render shader module",
        code: wgsl
    });

    return await device.createRenderPipelineAsync({
        label: "render buffer pipeline",
        layout: device.createPipelineLayout({
            label: "render buffer pipeline layout",
            bindGroupLayouts: [ window.render.bind_group_layout ]
        }),
        vertex: { module: shader, entryPoint: "vertex" },
        fragment: { module: shader, entryPoint: "fragment",
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
            }]
        },
    });
}

function render_grid(command_encoder:GPUCommandEncoder, ctx:GPUCanvasContext, render_pipeline:GPURenderPipeline) {
    const render_pass = command_encoder.beginRenderPass({
        label: "render pass",
        colorAttachments: [{
            clearValue: [0.0, 0.0, 0.0, 1.0],
            loadOp: `clear`,
            storeOp: `store`,
            view: ctx.getCurrentTexture().createView(),
        }]
    });
    render_pass.setPipeline(render_pipeline);
    render_pass.setBindGroup(0, window.render.bind_group);
    render_pass.draw(3);
    render_pass.end();
}

export { return_render_pipeline, render_grid }