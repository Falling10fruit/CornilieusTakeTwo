import { invoke } from "@tauri-apps/api/core";
import { Entity } from "../entities/baseEntity.ts"
import { print_bits } from "../../bit_utils.ts";
import entity_type_data from "../../json/entities/entities.json"
import sprite_indicies from "../../json/sprites/sprite_indicies.json"

let device: GPUDevice;
let pipeline: GPUComputePipeline;
let bindGroup_entities_0: GPUBindGroup;
let bindGroup_entities_1: GPUBindGroup;
let bindGroup_targetSprites: GPUBindGroup;
let bindGroup_additionalData: GPUBindGroup;

async function setUpComputeEntities(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;

    const computeModule = await loadComputeShader(device) as GPUShaderModule;
    const bindGroupLayout_entities = device.createBindGroupLayout({
        label: `compute entities data bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }}, // entity type data
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }}, // entity node data
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage"           }}, // entities indicies (creation order -> index in buffer)
            { binding: 3, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage"           }}, // chunk indicies (chunk no. -> index of first entity in chunk)
            { binding: 4, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage"           }}, // entity buffer 0
            { binding: 5, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage"           }}, // entity buffer 1
            { binding: 6, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage"           }}, // entity meta buffer
        ]
    });
    
    const bindGroupLayout_additionalData = device.createBindGroupLayout({
        label: `compute entities additional data bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage"           }}, // debug buffer to transfer one u32 fromt the gpu
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }}, // vec2u(cos, sin) look up table
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }}, // hilbert curve table
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }}, // world data
        ]
    });
    
    const bindGroupLayout_targetSprites = device.createBindGroupLayout({
        label: `compute entities sprites bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}, // target sprites buffer
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
            entryPoint: `cShader`,
            constants: {
                "WORLD_WIDTH_IN_CHUNKS": window.world.width,
                "WORLD_HEIGHT_IN_CHUNKS": window.world.height,
                "CHUNK_LENGTH": 8
            }
        }
    });

    if (window.world.entities.type_data_buffer  == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.type_data_buffer  is null" });
    if (window.world.entities.node_data_buffer  == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.node_data_buffer  is null"} );
    if (window.world.entities.entities_indicies == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.entities_indicies is null" });
    if (window.world.entities.chunk_indicies    == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.chunk_indicies    is null" });
    if (window.world.entities.entities_buffer_0 == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.entities_buffer_0 is null" });
    if (window.world.entities.entities_buffer_1 == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.entities_buffer_1 is null" });
    if (window.world.entities.meta_buffer       == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.meta_buffer       is null" });
    if (window.debug.buffer                     == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.debug.buffer                     is null" });
    if (window.cosin_lut_buffer                 == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.cosin_lut_buffer                 is null" });
    if (window.world.chunk_hilbert_curve_buffer == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.chunk_hilbert_curve_buffer is null" });
    if (window.world.storageBuffer              == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.storageBuffer              is null" });
    if (window.spritesBuffer.target             == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.spritesBuffer.target             is null" });

    bindGroup_entities_0 = device.createBindGroup({
        label: `compute entities data 0 - 1 bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.world.entities.type_data_buffer  }},
            { binding: 1, resource: { buffer: window.world.entities.node_data_buffer  }},
            { binding: 2, resource: { buffer: window.world.entities.entities_indicies }},
            { binding: 3, resource: { buffer: window.world.entities.chunk_indicies    }},
            { binding: 4, resource: { buffer: window.world.entities.entities_buffer_0 }},
            { binding: 5, resource: { buffer: window.world.entities.entities_buffer_1 }},
            { binding: 6, resource: { buffer: window.world.entities.meta_buffer       }},
        ]
    });
    
    
    bindGroup_entities_1 = device.createBindGroup({
        label: `compute entities data 0 - 1 bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: window.world.entities.type_data_buffer  }},
            { binding: 1, resource: { buffer: window.world.entities.node_data_buffer  }},
            { binding: 2, resource: { buffer: window.world.entities.entities_indicies }},
            { binding: 3, resource: { buffer: window.world.entities.chunk_indicies    }},
            { binding: 4, resource: { buffer: window.world.entities.entities_buffer_1 }},
            { binding: 5, resource: { buffer: window.world.entities.entities_buffer_0 }},
            { binding: 6, resource: { buffer: window.world.entities.meta_buffer       }},
        ]
    });

    bindGroup_additionalData = device.createBindGroup({
        label: `compute entities additional data bind group`,
        layout: pipeline.getBindGroupLayout(2),
        entries: [
            { binding: 0, resource: { buffer: window.debug.buffer                     }},
            { binding: 1, resource: { buffer: window.cosin_lut_buffer                 }},
            { binding: 2, resource: { buffer: window.world.chunk_hilbert_curve_buffer }},
            { binding: 3, resource: { buffer: window.world.storageBuffer              }},
        ]
    });
    
    bindGroup_targetSprites = device.createBindGroup({
        label: `compute entities target sprites bind group`,
        layout: pipeline.getBindGroupLayout(1),
        entries: [
            { binding: 0, resource: { buffer: window.spritesBuffer.target }},
        ]
    });

    write_entity_type_data();
}

function write_entity_type_data () {
    // struct EntityData {
    //     node_count: u32,
    //     node_pointer: u32,
    //     center: vec2f,
    //     dimensions: vec2f,
    //     mass: f32,
    //     default_sprite: u32
    // }
    const entity_type_data_array = new ArrayBuffer(entity_type_data.length * 8 * 4);
    const entity_type_data_array_u32 = new Uint32Array(entity_type_data_array);
    const entity_type_data_array_f32 = new Float32Array(entity_type_data_array);

    let prefix_count = 0;
    const node_pointer_indicies = entity_type_data.map((current_type_data) => {
        const temp = prefix_count;
        prefix_count += current_type_data.nodes.length;
        return temp;
    });
    
    for (let i = 0; i < entity_type_data.length; i++) {
        const current_type_data = entity_type_data[i];
        entity_type_data_array_u32[i * 8 * 4 + 0 ] = current_type_data.nodes.length;
        entity_type_data_array_u32[i * 8 * 4 + 4 ] = node_pointer_indicies[i];
        entity_type_data_array_f32[i * 8 * 4 + 8 ] = current_type_data.center[0];
        entity_type_data_array_f32[i * 8 * 4 + 12] = current_type_data.center[1];
        entity_type_data_array_f32[i * 8 * 4 + 16] = current_type_data.dimensions[0];
        entity_type_data_array_f32[i * 8 * 4 + 20] = current_type_data.dimensions[1];
        entity_type_data_array_f32[i * 8 * 4 + 24] = current_type_data.mass;
        entity_type_data_array_u32[i * 8 * 4 + 28] = sprite_indicies[current_type_data.default_sprite as keyof typeof sprite_indicies] ?? 0;
    }

    device.queue.writeBuffer(window.world.entities.type_data_buffer, 0, entity_type_data_array, 0, entity_type_data_array.byteLength);
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