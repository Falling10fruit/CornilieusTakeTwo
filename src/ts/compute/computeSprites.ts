import { invoke } from "@tauri-apps/api/core";
import { shift_left, add32Uints } from "../../bit_utils";

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
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // current sprites buffer
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // target sprites buffer
            { binding: 3, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" }} as GPUBindGroupLayoutEntry,
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
            { binding: 0, resource: { buffer: window.debug.buffer }}             as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.spritesBuffer.current }}    as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.spritesBuffer.target }}     as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.world.dimensionsUniform }}  as GPUBindGroupEntry,
        ]
    });
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_sprite_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute sprites shader", code: computeShaderSource });
}

async function createPlaceholderSprites() {
    const sprites = new Uint32Array(window.world.NO_OF_SPRITES * 2);
    sprites[0] = add32Uints(
        ( 1 << 7 ) // position zero rotation zero
    );

    if (window.spritesBuffer.current == null) return window.fail({ title: "\"current\" sprite buffer is null", message: "spritesBuffer of key \"current\" failed to initialize"});
    if (window.spritesBuffer.target == null) return window.fail({ title: "\"sprite\" buffer is null", message: "spritesBuffer of ket \"target\" failed to initialize"});
    device.queue.writeBuffer(window.spritesBuffer.current, 0, sprites, 0, 4);
    device.queue.writeBuffer(window.spritesBuffer.target, 0, sprites, 0, 4);
}

function computeSprites(pass: GPUComputePassEncoder) {
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.dispatchWorkgroups(DISPATCH_PER_DIMENSION);
}

export { setUpComputeSprites, computeSprites, createPlaceholderSprites }