import { invoke } from "@tauri-apps/api/core";

let device: GPUDevice;
let ctx: GPUCanvasContext;

async function setUpComputeSprites(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    ctx = parameters.ctx;

    const sprites = new Uint32Array(2**24);

    const IDK_ONE_SPRITE_IG_AS_TEST  = add32Uints(
        ( 0 << 25 ) >>> 0,
        ( 0 << 18 ) >>> 0,
        ( 0  << 9 ) >>> 0,
        ( 1  << 0 ) >>> 0
    ) >>> 0;
    sprites[0] = IDK_ONE_SPRITE_IG_AS_TEST;
    
    window.spritesBuffer = { current: createSpritesBufferOfSize(2**24), target: createSpritesBufferOfSize(2**24)};
    if (window.spritesBuffer.current == null) return window.fail({ title: "\"current\" sprite buffer is null", message: "spritesBuffer of key \"current\" failed to initialize"});
    if (window.spritesBuffer.target == null) return window.fail({ title: "\"sprite\" buffer is null", message: "spritesBuffer of ket \"target\" failed to initialize"});
    device.queue.writeBuffer(window.spritesBuffer.current, 0, sprites, 0, 2**24);
    device.queue.writeBuffer(window.spritesBuffer.target, 0, sprites, 0, 2**24);

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
    const pipeline = await device.createComputePipelineAsync({
        label: `compute sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `compute sprites pipeline layout`,
            bindGroupLayouts: [bindGroupLayout]
        }),
        compute: {
            module: computeModule,
            entryPoint: `cShader`
        }
    })
    
}

async function loadComputeShader(device: GPUDevice) {
    const computeShaderSource = await invoke("get_sprite_compute_shader").catch((e) => { return e });
    if (typeof computeShaderSource != "string") return window.fail({ title: "failed to retrieve", message: computeShaderSource});
    return device.createShaderModule({ label: "compute sprites shader", code: computeShaderSource });
}

function createSpritesBufferOfSize(amountOfSprites: number) {
    return device.createBuffer({
        label: "Sprites buffer",
        size: amountOfSprites * 4, // a u32 for each of the 16777216 sprites, should be more actually to accomodate for both entities and particles
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
}

function add32Uints(...numbers: number[]) {
    let sum = 0;
    for (let i = 0; i < numbers.length; i++) { sum = (sum + numbers[i]) >>> 0; }
    return sum;
}

export { setUpComputeSprites }