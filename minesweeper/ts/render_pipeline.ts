import wgsl from "../webgpu/render_buffer.wesl?static"

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

export { return_render_pipeline }