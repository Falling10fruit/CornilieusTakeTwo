import { invoke } from '@tauri-apps/api/core'

let device: GPUDevice;
let ctx: GPUCanvasContext;
let pipeline: GPUComputePipeline;
let bindGroup: GPUBindGroup;

async function bufferInput(device : GPUDevice) {
    const player_inputs = await invoke("get_player_inputs").catch((e) => { return e });
    if (!(player_inputs instanceof Array)) return window.fail({ title: "Couldn't get player inputs", message: player_inputs});

    if (window.world.playerInputBuffer == null) return window.fail({ title: "Player input buffer is null", message: "From src\ts\compute\playerInput.ts"});
    device.queue.writeBuffer(window.world.playerInputBuffer, 0, new Uint32Array(player_inputs));
    
    // const commandEncoder = device.createCommandEncoder({ label: `compute entities command encoder` });
    
    // if (window.world.playerInputBufferMapped == null) return window.fail({ title: `player input buffer mapped is null`, message: `message generated in playerInputs.ts`});
    // const readBuffer = device.createBuffer({ label: `generateWorld readBuffer`, size: window.world.NO_OF_PLAYERS * 8 + 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST});
    // commandEncoder.copyBufferToBuffer(window.world.playerInputBuffer, window.world.playerInputBufferMapped);
    
    // device.queue.submit([commandEncoder.finish()]);

    // readBuffer.mapAsync(GPUMapMode.READ).then(() => {
    //     console.log(new Uint32Array(readBuffer.getMappedRange()));
    //     readBuffer.unmap();
    // });

    // requestAnimationFrame(simulateEntities);
}

async function setUpComputeInputs(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    ctx = parameters.ctx;

    const computeModule = await loadComputeShader(device) as GPUShaderModule;
    const bindGroupLayout = device.createBindGroupLayout({
        label: `compute sprites bind gorup layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // current sprites buffer
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry // target sprites buffer
        ]
    });

    pipeline = await device.createComputePipelineAsync({
        label: `compute sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `compute sprites pipeline layout`,
            bindGroupLayouts: [bindGroupLayout]
        }),
        compute: {
            module: computeModule,
            entryPoint: `cShader_sprites`
        }
    });
  
    bindGroup = device.createBindGroup({
        label: `compute sprites bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.debug.buffer }}          as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.spritesBuffer.current }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.spritesBuffer.target }}  as GPUBindGroupEntry,
        ]
    });
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_input_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute inputs shader", code: computeShaderSource });
}

function computeInputs(pass: GPUComputePassEncoder) {
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.dispatchWorkgroups(1);
}

export { bufferInput }