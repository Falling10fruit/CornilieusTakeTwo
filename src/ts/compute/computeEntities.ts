import { invoke } from "@tauri-apps/api/core";
import { Entity } from "../entities/baseEntity.ts"

let device: GPUDevice;
let pipeline: GPUComputePipeline;
let bindGroup_entities_0: GPUBindGroup;
let bindGroup_entities_1: GPUBindGroup;
let bindGroup_targetSprites: GPUBindGroup;
let bindGroup_additionalData: GPUBindGroup;

let NO_OF_DISPATCHES: number;

async function setUpComputeEntities(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    NO_OF_DISPATCHES = Math.ceil(window.world.NO_OF_SPRITES / 256);

    const computeModule = await loadComputeShader(device) as GPUShaderModule;
    const bindGroupLayout_entities = device.createBindGroupLayout({
        label: `compute entities data bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entities indicies (creation order -> index in buffer)
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // chunk indicies (chunk no. -> index of first entity in chunk)
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entity buffer 0
            { binding: 3, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // entity buffer 1
        ]
    });
    
    const bindGroupLayout_targetSprites = device.createBindGroupLayout({
        label: `compute entities sprites bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }} as GPUBindGroupLayoutEntry, // target sprites buffer
        ]
    });
    
    const bindGroupLayout_additionalData = device.createBindGroupLayout({
        label: `compute entities player input bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }} as GPUBindGroupLayoutEntry, // players' input (first index is player count)
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" }}           as GPUBindGroupLayoutEntry, // world dimensions in blocks not chunks
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }} as GPUBindGroupLayoutEntry, // world data
        ]
    });

    pipeline = await device.createComputePipelineAsync({
        label: `compute entities pipeline`,
        layout: device.createPipelineLayout({
            label: `compute entities pipeline layout`,
            bindGroupLayouts: [
                bindGroupLayout_entities,
                bindGroupLayout_targetSprites,
                bindGroupLayout_additionalData
            ]
        }),
        compute: {
            module: computeModule,
            entryPoint: `cShader`
        }
    });
  
    bindGroup_entities_0 = device.createBindGroup({
        label: `compute entities data 0 - 1 bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.entitiesBuffer.entities_indicies }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.entitiesBuffer.chunk_indicies }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.entitiesBuffer.entities_buffer_0 }} as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.entitiesBuffer.entities_buffer_1 }} as GPUBindGroupEntry,
        ]
    });
    
    bindGroup_entities_1 = device.createBindGroup({
        label: `compute entities data 1 - 0 bind group`,
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

    bindGroup_additionalData = device.createBindGroup({
        label: `compute entities additional data bind group`,
        layout: pipeline.getBindGroupLayout(2),
        entries: [
            { binding: 0, resource: { buffer: window.world.playerInputBuffer }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.world.dimensionsUniform }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.world.storageBuffer     }} as GPUBindGroupEntry
        ]
    })

    createPlaceholderEntities();
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_entity_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute entities shader", code: computeShaderSource });
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
    pass.setBindGroup(2, bindGroup_additionalData);
    pass.dispatchWorkgroups(NO_OF_DISPATCHES);
    
    window.entitiesBuffer.current_entity_buffer_is = window.entitiesBuffer.current_entity_buffer_is == 0 ? 1 : 0;
}

function createPlaceholderEntities() {
    const { entities_indicies, chunk_indicies, entities_buffer_0, entities_buffer_1} = window.entitiesBuffer;

    if (entities_indicies == null) return window.fail({ title: `Entities indicies buffer 0 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});
    if (chunk_indicies == null) return window.fail({ title: `Chunk indicies 1 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});
    if (entities_buffer_0 == null) return window.fail({ title: `Entity buffer 0 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});
    if (entities_buffer_1 == null) return window.fail({ title: `Entity buffer 1 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});

    device.queue.writeBuffer(entities_indicies, 0, new Uint32Array(0));
    device.queue.writeBuffer(chunk_indicies, 0, new Uint32Array(0));
    device.queue.writeBuffer(entities_buffer_0, 0, (new Entity()).serialized_representation());
}

function add32Uints(...numbers: number[]) {
    let sum = 0;
    for (let i = 0; i < numbers.length; i++) { sum = (sum + numbers[i]) >>> 0; }
    return sum;
}

export { setUpComputeEntities, computeEntities, createPlaceholderEntities }