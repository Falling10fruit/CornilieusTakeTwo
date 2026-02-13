import { invoke } from "@tauri-apps/api/core";

let device: GPUDevice;
let ctx: GPUCanvasContext;
let pipeline: GPUComputePipeline;
let bindGroup: GPUBindGroup;

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
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // current sprites buffer
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry // target sprites buffer
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
            { binding: 0, resource: { buffer: window.spritesBuffer.current }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
        ]
    });

    createPlaceholderSprites();
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_sprite_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute sprites shader", code: computeShaderSource });
}

function createPlaceholderSprites() {
    if (window.spritesBuffer.current == null) return window.fail({ title: `"current" sprites buffer are null`,  message: `window.spritesBuffer.current is null`});
    if (window.spritesBuffer.target == null) return window.fail({ title: `"target" sprites buffer are null`,  message: `window.spritesBuffer.target is null`});

    const current = new Int32Array(window.spritesBuffer.NO_OF_SPRITES);
    const currentEntityPlaceholder = add32Uints(
        ( 0 << 25 ) >>> 0,
        ( 0 << 18 ) >>> 0,
        ( 0  << 9 ) >>> 0,
        ( 1  << 0 ) >>> 0
    ) >>> 0;
    current[0] = currentEntityPlaceholder;

    const target = new Int32Array(window.spritesBuffer.NO_OF_SPRITES);
    const targetEntityPlaceholder = add32Uints(
        ( 0 << 25 ) >>> 0,
        ( 0 << 18 ) >>> 0,
        ( 0  << 9 ) >>> 0,
        ( 1  << 0 ) >>> 0
    ) >>> 0;
    target[0] = targetEntityPlaceholder;

    device.queue.writeBuffer(window.spritesBuffer.current, 0, current);
    device.queue.writeBuffer(window.spritesBuffer.target, 0, target);
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
    pass.setBindGroup(0, bindGroup);
    pass.dispatchWorkgroups(DISPATCH_PER_DIMENSION, DISPATCH_PER_DIMENSION); //
}

export { setUpComputeSprites, computeSprites }