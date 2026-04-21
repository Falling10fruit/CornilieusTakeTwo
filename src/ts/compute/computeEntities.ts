import { invoke } from "@tauri-apps/api/core";
import { Entity } from "../entities/baseEntity.ts"
import { print_bits } from "../../bit_utils.ts";
import { computeInputs } from "./playerInput.ts";

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
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}           as GPUBindGroupLayoutEntry, // debug buffer to transfer one u32 fromt the gpu
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
            { binding: 0, resource: { buffer: window.world.entities.entities_indicies }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.world.entities.chunk_indicies }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.world.entities.entities_buffer_0 }} as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.world.entities.entities_buffer_1 }} as GPUBindGroupEntry,
        ]
    });
    
    bindGroup_entities_1 = device.createBindGroup({
        label: `compute entities data 1 - 0 bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.world.entities.entities_indicies }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.world.entities.chunk_indicies }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.world.entities.entities_buffer_1 }} as GPUBindGroupEntry,
            { binding: 3, resource: { buffer: window.world.entities.entities_buffer_0 }} as GPUBindGroupEntry,
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
            { binding: 0, resource: { buffer: window.debug.buffer            }} as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.world.dimensionsUniform }} as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.world.storageBuffer     }} as GPUBindGroupEntry
        ]
    })
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_entity_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute entities shader", code: computeShaderSource });
}

async function createPlaceholderEntities() {
    const { entities_indicies, chunk_indicies, entities_buffer_0, entities_buffer_1} = window.world.entities;

    if (entities_indicies == null) return window.fail({ title: `Entities indicies buffer 0 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});
    if (chunk_indicies == null) return window.fail({ title: `Chunk indicies 1 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});
    if (entities_buffer_0 == null) return window.fail({ title: `Entity buffer 0 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});
    if (entities_buffer_1 == null) return window.fail({ title: `Entity buffer 1 is null`,  message: `Message generated at computeEntities.ts while trying to generate placeholder entities`});

    device.queue.writeBuffer(chunk_indicies, 0, new Uint32Array([0]));
    
    const placeholder_entity_0 = new Entity({
        entity_type: 1,
        global_x_position : 0,
        global_y_position : 0,
        rotation : 0,
        x_velocity : 0,
        y_velocity : 0,
        rotation_velocity : 0
    }).serialized_representation();
    
    const placeholder_entity_1 = new Entity({
        entity_type: 3,
        global_x_position : 10,
        global_y_position : 26,
        rotation : 0,
        x_velocity : 0,
        y_velocity : 0,
        rotation_velocity : 0
    }).serialized_representation();
    // print_bits(serialized[2]);
    device.queue.writeBuffer(entities_indicies, 0, new Uint32Array([0, 1]));
    device.queue.writeBuffer(entities_buffer_0, 0, new Uint32Array([...placeholder_entity_0, ...placeholder_entity_1]));
    device.queue.writeBuffer(entities_buffer_1, 0, new Uint32Array([...placeholder_entity_0, ...placeholder_entity_1]));
}

function computeEntities(pass: GPUComputePassEncoder) {
    pass.setPipeline(pipeline);
    if (window.world.entities.current_entity_buffer_is == 0) {
        pass.setBindGroup(0, bindGroup_entities_0);
    } else {
        pass.setBindGroup(0, bindGroup_entities_1);
    }

    pass.setBindGroup(1, bindGroup_targetSprites);
    pass.setBindGroup(2, bindGroup_additionalData);
    
    if (window.world.entities.indirect_count_buffer == null) return window.fail({ title: "indirect buffer missing", message: "while computing entities"});
    pass.dispatchWorkgroupsIndirect(window.world.entities.indirect_count_buffer, 0);
}

export { setUpComputeEntities, computeEntities, createPlaceholderEntities }