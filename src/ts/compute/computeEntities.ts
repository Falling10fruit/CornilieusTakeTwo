import { invoke } from "@tauri-apps/api/core";

let device: GPUDevice;
let pipeline: GPUComputePipeline;
let bindGroup_entities_0: GPUBindGroup;
let bindGroup_entities_1: GPUBindGroup;
let bindGroup_targetSprites: GPUBindGroup;
let bindGroup_playerInput: GPUBindGroup;

let DISPATCH_PER_DIMENSION: number;

async function setUpComputeEntities(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    DISPATCH_PER_DIMENSION = Math.sqrt(window.world.NO_OF_SPRITES / 256);

    const computeModule = await loadComputeShader(device) as GPUShaderModule;
    const bindGroupLayout_entities = device.createBindGroupLayout({
        label: `compute sprites bind gorup layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entities indicies (creation order -> index in buffer)
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // chunk indicies (chunk no. -> index of first entity in chunk)
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // current entity buffer
            { binding: 3, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entity buffer 0
            { binding: 4, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entity buffer 1
        ]
    });
    
    const bindGroupLayout_targetSprites = device.createBindGroupLayout({
        label: `compute sprites bind gorup layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // target sprites buffer
        ]
    });
    
    const bindGroupLayout_playerInput = device.createBindGroupLayout({
        label: `compute sprites bind gorup layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // players' input (first index is player count)
        ]
    });

    pipeline = await device.createComputePipelineAsync({
        label: `compute sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `compute sprites pipeline layout`,
            bindGroupLayouts: [
                bindGroupLayout_entities,
                bindGroupLayout_targetSprites,
                bindGroupLayout_playerInput
            ]
        }),
        compute: {
            module: computeModule,
            entryPoint: `cShader`
        }
    });
  
    bindGroup_entities_0 = device.createBindGroup({
        label: `compute sprites bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.entitiesBuffer.entities_indicies }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.entitiesBuffer.chunk_indicies }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.entitiesBuffer.entities_buffer_0 }} as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.entitiesBuffer.entities_buffer_1 }} as GPUBindGroupEntry,
        ]
    });
    
    bindGroup_entities_1 = device.createBindGroup({
        label: `compute sprites bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.entitiesBuffer.entities_indicies }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.entitiesBuffer.chunk_indicies }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.entitiesBuffer.entities_buffer_1 }} as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.entitiesBuffer.entities_buffer_0 }} as GPUBindGroupEntry,
        ]
    });

    bindGroup_targetSprites = device.createBindGroup({
        label: `compute entities target sprites bind group`,
        layout: pipeline.getBindGroupLayout(1),
        entries: [
            { binding: 0, resource: { buffer: window.spritesBuffer.target }} as GPUBindGroupEntry,
        ]
    });

    bindGroup_playerInput = device.createBindGroup({
        label: `compute entities player input bind group`,
        layout: pipeline.getBindGroupLayout(2),
        entries: [
            { binding: 0, resource: { buffer: window.world.playerInputBuffer }} as GPUBindGroupEntry,
        ]
    })

    createPlaceholderEntities();
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_entity_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute sprites shader", code: computeShaderSource });
}

function createPlaceholderEntities() {
    if (window.entitiesBuffer.entities_buffer_0 == null) return window.fail({ title: `Entity buffer 0 is null`,  message: `Message generated at computeEntities.ts`});
    if (window.entitiesBuffer.entities_buffer_1 == null) return window.fail({ title: `Entity buffer 1 is null`,  message: `Message generated at computeEntities.ts`});

}

function add32Uints(...numbers: number[]) {
    let sum = 0;
    for (let i = 0; i < numbers.length; i++) { sum = (sum + numbers[i]) >>> 0; }
    return sum;
}

function computeEntities(pass: GPUComputePassEncoder) {
    pass.setPipeline(pipeline);
    
    if (window.entitiesBuffer.current_entity_buffer_is == 0) {
        pass.setBindGroup(0, bindGroup_entities_0);
        window.entitiesBuffer.current_entity_buffer_is = 1;
    } else {
        pass.setBindGroup(0, bindGroup_entities_1);
        window.entitiesBuffer.current_entity_buffer_is = 0;
    }

    pass.setBindGroup(1, bindGroup_targetSprites);
    pass.setBindGroup(2, bindGroup_playerInput);
    pass.dispatchWorkgroups(DISPATCH_PER_DIMENSION, DISPATCH_PER_DIMENSION);
}

export { setUpComputeEntities, computeEntities }