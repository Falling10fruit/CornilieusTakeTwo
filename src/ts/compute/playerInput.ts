import { invoke } from '@tauri-apps/api/core'

let device: GPUDevice;
let ctx: GPUCanvasContext;
let pipeline: GPUComputePipeline;
let bind_group_0: GPUBindGroup;
let bind_group_1: GPUBindGroup;

async function bufferInput(device : GPUDevice) {
    const player_inputs = await invoke("get_player_inputs").catch((e) => { return e });
    if (!(player_inputs instanceof Array)) return window.fail({ title: "Couldn't get player inputs", message: player_inputs});

    if (window.world.playerInputBuffer == null) return window.fail({ title: "Player input buffer is null", message: "From src\ts\compute\playerInput.ts"});
    device.queue.writeBuffer(window.world.playerInputBuffer, 0, new Uint32Array(player_inputs));
}

async function setUpComputeInputs(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    ctx = parameters.ctx;

    const computeModule = await loadComputeShader(device) as GPUShaderModule;
    const bind_group_layout = device.createBindGroupLayout({
        label: `compute input bind gorup layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" }}           as GPUBindGroupLayoutEntry,
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }} as GPUBindGroupLayoutEntry,
            { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}           as GPUBindGroupLayoutEntry
        ]
    });
  
    bind_group_0 = device.createBindGroup({
        label: `compute input bind group 0`,
        layout: bind_group_layout,
        entries: [
            { binding: 0, resource: { buffer: window.world.playerCountUniform }}         as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.world.playerInputBuffer }}          as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.entitiesBuffer.entities_buffer_0 }} as GPUBindGroupEntry,
        ]
    });
  
    bind_group_1 = device.createBindGroup({
        label: `compute input bind group 1`,
        layout: bind_group_layout,
        entries: [
            { binding: 0, resource: { buffer: window.world.playerCountUniform }}         as GPUBindGroupEntry,
            { binding: 1, resource: { buffer: window.world.playerInputBuffer }}          as GPUBindGroupEntry,
            { binding: 2, resource: { buffer: window.entitiesBuffer.entities_buffer_1 }} as GPUBindGroupEntry,
        ]
    });

    pipeline = await device.createComputePipelineAsync({
        label: `compute input pipeline`,
        layout: device.createPipelineLayout({
            label: `compute input pipeline layout`,
            bindGroupLayouts: [bind_group_layout]
        }),
        compute: {
            module: computeModule,
            entryPoint: `cShader_input`
        }
    });
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_input_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute inputs shader", code: computeShaderSource });
}

function computeInputs(pass: GPUComputePassEncoder) {
    pass.setPipeline(pipeline);

    if (window.entitiesBuffer.current_entity_buffer_is == 0) {
        pass.setBindGroup(0, bind_group_0);
    } else {
        pass.setBindGroup(0, bind_group_1);
    }
    
    pass.dispatchWorkgroups(1);
}

export { bufferInput, setUpComputeInputs, computeInputs }