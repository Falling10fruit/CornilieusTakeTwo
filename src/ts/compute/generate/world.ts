import generate_world_source from "../../../wgsl/world/generate.wgsl?raw";

let device: GPUDevice;
let bindGroupLayout: GPUBindGroupLayout;
let pipeline: GPUComputePipeline;

/** Initializes methods for the [generateWorld](generateWorldShader.ts) module.
 * 
 * Implementation at {@link setUpGenerateWorld} */
async function setUpGenerateWorld (parameters: { device: GPUDevice }) {
    device = parameters.device;

    const computeShader = device.createShaderModule({
        label: `generate world shader`,
        code: generate_world_source
    });

    bindGroupLayout = device.createBindGroupLayout({
        label: `generate world bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.COMPUTE,
            buffer: { type: "storage" }
        }]
    });

    pipeline = await device.createComputePipelineAsync({
        label: `generate world pipeline`,
        layout: device.createPipelineLayout({
            label: `generate world pipeline layout`,
            bindGroupLayouts: [bindGroupLayout],
        }),
        compute: {
            module: computeShader,
            entryPoint: "cShader",
        }
    });
}

async function generateWorldToBuffer () {
    const { width, height } = window.world;

    if (window.world.storageBuffer == null) return window.fail({ title: `world storage buffer is null`, message: `error generated at generateWorldShader`})
    const bindGroup = device.createBindGroup({
        label: `generate world bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [{ binding: 0, resource: { buffer: window.world.storageBuffer } }]
    });

    const encoder = device.createCommandEncoder({ label: `generate world command encoder` });
    const pass = encoder.beginComputePass({ label: `generate world compute pass` });
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.dispatchWorkgroups(width, height);
    pass.end();

    // const readBuffer = device.createBuffer({ label: `generateWorld readBuffer`, size: width * height * 64 * 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST});
    // encoder.copyBufferToBuffer(window.world.storageBuffer, readBuffer);

    device.queue.submit([encoder.finish()]);

    // readBuffer.mapAsync(GPUMapMode.READ).then(() => {
    //     console.log(new Uint32Array(readBuffer.getMappedRange().slice(0, 1600)));
    //     readBuffer.unmap();
    // });
}

export { setUpGenerateWorld, generateWorldToBuffer }