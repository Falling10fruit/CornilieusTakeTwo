import { add32Uints } from "../../bit_utils";
import { createPlaceholderEntities } from "../compute/computeEntities";

let device: GPUDevice;

function createBuffers(parameters: { device: GPUDevice }) {
    device = parameters.device;
    createDebugBuffers();

    createRenderBuffers();
    createComputeBuffers();
}

function createComputeBuffers() {
    updateEntitiesData();
    createInputBuffers();
}

function createRenderBuffers() {
    createCameraUniform();
    createCanvasDimensionUniform();
    createPlaceholderWorldDataBuffer();
    createPlaceholderSprites();
}

function createDebugBuffers() {
    window.debug.buffer = device.createBuffer({ label: `debug storage buffer`,
        size: 4, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC
    });
    
    window.debug.unmapped_buffers = [];
    for (let i = 0; i < 3; i++) {
        window.debug.unmapped_buffers.push(device.createBuffer({ label: `debug mapped buffer`,
            size: 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
        }));
    }
}

function createCameraUniform() {
    window.camera.uniformBuffer = device.createBuffer({
        label: `camera tranform uniform`,
        size: 2 * 4 + // vec2
              1 * 4 + // f32
              1 * 4 + // f32
              0 * 4 , // + padding
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });
}

function createCanvasDimensionUniform() {
    window.viewportUniform = device.createBuffer({
        label: `render world viewport uniform`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });
}

function createPlaceholderWorldDataBuffer() {
    window.world.width = 160;
    window.world.height = 120;
    updateWorldData({ ...window.world })
}

function updateWorldData (parameters: { width: number, height: number }) {
    window.world.dimensionsUniform = device.createBuffer({
        label: `world dimensions uniform`,
        size: 4 * 2,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
    device.queue.writeBuffer(
        window.world.dimensionsUniform,
        0, new Uint32Array([ parameters.width, parameters.height ])
    );

    window.world.storageBuffer = device.createBuffer({
        label: `world data buffer`,
        size: parameters.width * parameters.height * 64 * 4, // 8 * 8 tiles per chunk, 4 bytes each
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
}

function createPlaceholderSprites() {
    window.spritesBuffer.current = device.createBuffer({
        label: `current sprites buffer`,
        size: window.world.NO_OF_SPRITES * 4,
        usage: GPUBufferUsage.COPY_SRC | GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
    })
    
    window.spritesBuffer.target = device.createBuffer({
        label: `target sprites buffer`,
        size: window.world.NO_OF_SPRITES * 4,
        usage: GPUBufferUsage.COPY_SRC | GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
    })
    
    const sprites = new Uint32Array(2**24);
    const IDK_ONE_SPRITE_IG_AS_TEST  = add32Uints(
        ( 0 << 25 ) >>> 0,
        ( 0 << 18 ) >>> 0,
        ( 0  << 9 ) >>> 0,
        ( 1  << 0 ) >>> 0
    ) >>> 0;
    sprites[0] = IDK_ONE_SPRITE_IG_AS_TEST;

    if (window.spritesBuffer.current == null) return window.fail({ title: "\"current\" sprite buffer is null", message: "spritesBuffer of key \"current\" failed to initialize"});
    if (window.spritesBuffer.target == null) return window.fail({ title: "\"sprite\" buffer is null", message: "spritesBuffer of ket \"target\" failed to initialize"});
    device.queue.writeBuffer(window.spritesBuffer.current, 0, sprites, 0, 4);
    device.queue.writeBuffer(window.spritesBuffer.target, 0, sprites, 0, 4);
}

function updateEntitiesData() {
    const entities_indicies = device.createBuffer({
        label: `entities indicies buffer`,
        size: window.world.NO_OF_ENTITIES * 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });

    const chunk_indicies = device.createBuffer({
        label: `chunk indicies buffer`,
        size: window.world.NO_OF_ENTITIES * 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });

    const buffer_0 = device.createBuffer({
        label: `entities texture 0`,
        size: window.world.NO_OF_ENTITIES * 4 * 7,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
    });

    const buffer_1 = device.createBuffer({
        label: `entities texture 0`,
        size: window.world.NO_OF_ENTITIES * 4 * 7,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
    });
    
    window.entitiesBuffer = {
        entities_indicies: entities_indicies,
        chunk_indicies: chunk_indicies,
        current_entity_buffer_is: 0,
        entities_buffer_0: buffer_0,
        entities_buffer_1: buffer_1,
    }
}

function createInputBuffers () {
    const playerCountUniform = device.createBuffer({
        label: `player count`,
        size: 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });
    window.world.playerCountUniform = playerCountUniform;

    const playerInputBuffer = device.createBuffer({
        label: `players inputs`,
        size: window.world.MAX_PLAYERS * 16,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    });

    window.world.playerInputBuffer = playerInputBuffer;

    const playerInputBufferMapped = device.createBuffer({
        label: `mapped player inputs`,
        size: window.world.MAX_PLAYERS * 16,
        usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
    });

    window.world.playerInputBufferMapped = playerInputBufferMapped;
}

export { createBuffers, updateWorldData }