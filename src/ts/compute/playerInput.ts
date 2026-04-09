import { invoke } from '@tauri-apps/api/core'

let device: GPUDevice;
let ctx: GPUCanvasContext;
let pipeline: GPUComputePipeline;
let bind_group_0: GPUBindGroup;
let bind_group_1: GPUBindGroup;

const current_input = {
    "q": 0,
    "w": 0,
    "e": 0,
    "a": 0,
    "s": 0,
    "d": 0,
    "tab": 0,
    "shift": 0,
    "ctrl": 0,
    "alt": 0,
    "mouse_left": 0,
    "mouse_middle": 0,
    "mouse_right": 0,
    "mouse_x": 0,
    "mouse_y": 0,
    "mouse_rotation": 0,
    "z": 0,
    "x": 0,
    "c": 0,
    "r": 0,
    "f": 0,
    "v": 0,
    "t": 0,
    "g": 0,
    "b": 0,
    "no_9": 0,
    "no_8": 0,
    "no_7": 0,
    "no_6": 0,
    "no_5": 0,
    "no_4": 0,
    "no_3": 0,
    "no_2": 0,
    "no_1": 0,
    "no_0": 0,
}

function uploadInput() {
    current_input.q = window.keyIsDown["q"] ? 1 : 0;
    current_input.w = window.keyIsDown["w"] ? 1 : 0;
    current_input.e = window.keyIsDown["e"] ? 1 : 0;
    current_input.a = window.keyIsDown["a"] ? 1 : 0;
    current_input.s = window.keyIsDown["s"] ? 1 : 0;

    current_input.d = window.keyIsDown["d"] ? 1 : 0;
    current_input.tab = window.keyIsDown["Tab"] ? 1 : 0;
    current_input.shift = window.keyIsDown["Shift"] ? 1 : 0;
    current_input.ctrl = window.keyIsDown["Control"] ? 1 : 0;
    current_input.alt = window.keyIsDown["Alt"] ? 1 : 0;
    current_input.mouse_left = 0;
    current_input.mouse_middle = 0;
    current_input.mouse_right = 0;
    current_input.mouse_x = 0;
    current_input.mouse_y = 0;

    current_input.mouse_rotation = 0;
    current_input.z = window.keyIsDown["z"] ? 1 : 0;
    current_input.x = window.keyIsDown["x"] ? 1 : 0;
    current_input.c = window.keyIsDown["c"] ? 1 : 0;
    current_input.r = window.keyIsDown["r"] ? 1 : 0;
    current_input.f = window.keyIsDown["f"] ? 1 : 0;
    current_input.v = window.keyIsDown["v"] ? 1 : 0;
    current_input.t = window.keyIsDown["t"] ? 1 : 0;
    current_input.g = window.keyIsDown["g"] ? 1 : 0;
    current_input.b = window.keyIsDown["b"] ? 1 : 0;
    current_input.no_9 = window.keyIsDown["9"] ? 1 : 0;
    current_input.no_8 = window.keyIsDown["8"] ? 1 : 0;
    current_input.no_7 = window.keyIsDown["7"] ? 1 : 0;
    current_input.no_6 = window.keyIsDown["6"] ? 1 : 0;
    current_input.no_5 = window.keyIsDown["5"] ? 1 : 0;
    current_input.no_4 = window.keyIsDown["4"] ? 1 : 0;
    current_input.no_3 = window.keyIsDown["3"] ? 1 : 0;
    current_input.no_2 = window.keyIsDown["2"] ? 1 : 0;
    current_input.no_1 = window.keyIsDown["1"] ? 1 : 0;
    current_input.no_0 = window.keyIsDown["q"] ? 1 : 0;

    const input_array = new Uint32Array([
            0
            + (current_input.q << 4)
            + (current_input.w << 3)
            + (current_input.e << 2)
            + (current_input.a << 1)
            + current_input.s,

            (current_input.d << 31)
            + (current_input.tab << 30)
            + (current_input.shift << 29)
            + (current_input.ctrl << 28)
            + (current_input.alt << 27)
            + (current_input.mouse_left << 26)
            + (current_input.mouse_middle << 25)
            + (current_input.mouse_right << 24)
            + (current_input.mouse_x << 12)
            + current_input.mouse_y,

            (current_input.mouse_rotation << 19)
            + (current_input.z << 18)
            + (current_input.x << 17)
            + (current_input.c << 16)
            + (current_input.r << 15)
            + (current_input.f << 14)
            + (current_input.v << 13)
            + (current_input.t << 12)
            + (current_input.g << 11)
            + (current_input.b << 10)
            + (current_input.no_9 << 9)
            + (current_input.no_8 << 8)
            + (current_input.no_7 << 7)
            + (current_input.no_6 << 6)
            + (current_input.no_5 << 5)
            + (current_input.no_4 << 4)
            + (current_input.no_3 << 3)
            + (current_input.no_2 << 2)
            + (current_input.no_1 << 1)
            + current_input.no_0
    ]);

    invoke("upload_player_inputs", { player_input_array: input_array });
}

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

export { bufferInput, setUpComputeInputs, computeInputs, uploadInput }