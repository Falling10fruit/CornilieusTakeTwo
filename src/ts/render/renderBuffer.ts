import shader_source from "../../wgsl/render_buffer.wgsl?raw";

let device: GPUDevice;
let bind_group: GPUBindGroup;
let pipeline: GPURenderPipeline;

async function setUpRenderBuffers (parameters: { device: GPUDevice}) {
    device = parameters.device;

    const bind_group_layout = device.createBindGroupLayout({
        label: `render buffer bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" } }
        ]
    });

    const shader_module = device.createShaderModule({
        label: `render buffer shader module`,
        code: shader_source
    });

    pipeline = await device.createRenderPipelineAsync({
        label: `render buffer pipeline`,
        layout: device.createPipelineLayout({
            label: `render buffer pipeline`,
            bindGroupLayouts: [bind_group_layout]
        }),
        vertex:   { module: shader_module, entryPoint: "vertex" },
        fragment: { module: shader_module, entryPoint: "fragment",
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
        }
    })

    bind_group = device.createBindGroup({
        label: `render buffer bind group`,
        layout: bind_group_layout,
        entries: [
            { binding: 0, resource: window.world.entities.entities_buffer_0 } as GPUBindGroupEntry
        ]
    });
}

function render_buffers(pass: GPURenderPassEncoder) {
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bind_group);
    pass.draw(3);
}

export { setUpRenderBuffers, render_buffers }