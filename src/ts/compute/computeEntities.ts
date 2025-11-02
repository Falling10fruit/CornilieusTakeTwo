import { invoke } from "@tauri-apps/api/core";

let device: GPUDevice;
let pipeline: GPUComputePipeline;
let bindGroup: GPUBindGroup;

let DISPATCH_PER_DIMENSION: number;

async function setUpComputeSprites(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    DISPATCH_PER_DIMENSION = Math.sqrt(window.world.NO_OF_SPRITES / 256);

    const computeModule = await loadComputeShader(device) as GPUShaderModule;
    const bindGroupLayout = device.createBindGroupLayout({
        label: `compute sprites bind gorup layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entities indicies (creation order -> index in buffer)
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // chunk indicies (chunk no. -> index of first entity in chunk)
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // current entity buffer
            { binding: 3, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entity buffer 0
            { binding: 4, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entity buffer 1
            { binding: 5, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // target sprites buffer
            { binding: 6, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // players' input (first index is player count)
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
  
    bindGroup = device.createBindGroup({
        label: `compute sprites bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.spritesBuffer.current }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
            { binding: 4, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
            { binding: 5, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
            { binding: 6, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
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