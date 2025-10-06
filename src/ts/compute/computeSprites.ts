import { invoke } from "@tauri-apps/api/core";

let device: GPUDevice;
let ctx: GPUCanvasContext;
let pipeline: GPUComputePipeline;

let DISPATCH_PER_DIMENSION: number;

async function setUpComputeSprites(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    ctx = parameters.ctx;
    DISPATCH_PER_DIMENSION = Math.sqrt(window.world.NO_OF_SPRITES / 256);
    
    // const stagingBuffer = device.createBuffer({
    //     label: "staging buffer for sprites",
    //     size: IDK_ONE_SPRITE_IG_AS_TEST.byteLength,
    //     usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
    // });
    
    // const stagingEncoder = device.createCommandEncoder({ label: "staging encoder for sprites" });
    // stagingEncoder.copyBufferToBuffer(
        //     window.spritesBuffer, 0,
        //     stagingBuffer, 0,
        //     IDK_ONE_SPRITE_IG_AS_TEST.byteLength
    // );
    // const stagingCommands = stagingEncoder.finish();
    // device.queue.submit([stagingCommands]);

    // stagingBuffer.mapAsync(GPUMapMode.READ).then(() => {
    //     console.log(new Uint32Array(stagingBuffer.getMappedRange()).slice(0, 10));
    //     stagingBuffer.unmap();
    // });

    const computeModule = await loadComputeShader(device) as GPUShaderModule;
    const bindGroupLayout = device.createBindGroupLayout({
        label: `compute sprites bind gorup layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry
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
            entryPoint: `cShader`
        }
    });
  
    window.bindGroups.render[3] = device.createBindGroup({
        label: `compute sprites bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.spritesBuffer.current }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
        ]
    });
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_sprite_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute sprites shader", code: computeShaderSource });
}

function createSpritesBufferOfSize(amountOfSprites: number) {
    return device.createBuffer({
        label: "Sprites buffer",
        size: amountOfSprites * 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
}

function add32Uints(...numbers: number[]) {
    let sum = 0;
    for (let i = 0; i < numbers.length; i++) { sum = (sum + numbers[i]) >>> 0; }
    return sum;
}

function computeSprites(pass: GPUComputePassEncoder) {
    pass.setPipeline(pipeline);
    pass.dispatchWorkgroups(DISPATCH_PER_DIMENSION, DISPATCH_PER_DIMENSION); //
}

export { setUpComputeSprites, computeSprites }