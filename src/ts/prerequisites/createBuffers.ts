let device: GPUDevice;

function createBuffers(parameters: { device: GPUDevice }) {
    device = parameters.device;

    createRenderBuffers();
}

function createRenderBuffers() {
    createCameraUniform();
    createCanvasDimensionUniform();
    createPlaceholderWorldDataBuffer();
    updateSpriteData();
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
    window.world.height = 160;
    window.world.width = 120;
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
        0, new Float32Array([ parameters.width, parameters.height ])
    );

    window.world.storageBuffer = device.createBuffer({
        label: `world data buffer`,
        size: parameters.width * parameters.height * 256 * 4, // 16 * 16 tiles per chunk, 4 bytes each
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
    });
}

function updateSpriteData() {
    const sprites = new Uint32Array(2**24);

    const IDK_ONE_SPRITE_IG_AS_TEST  = add32Uints(
        ( 0 << 25 ) >>> 0,
        ( 0 << 18 ) >>> 0,
        ( 0  << 9 ) >>> 0,
        ( 1  << 0 ) >>> 0
    ) >>> 0;
    sprites[0] = IDK_ONE_SPRITE_IG_AS_TEST;
    
    const NO_OF_SPRITES = window.world.NO_OF_SPRITES;
    window.spritesBuffer = { NO_OF_SPRITES: NO_OF_SPRITES, current: createSpritesBufferOfSize(NO_OF_SPRITES), target: createSpritesBufferOfSize(NO_OF_SPRITES)};
    if (window.spritesBuffer.current == null) return window.fail({ title: "\"current\" sprite buffer is null", message: "spritesBuffer of key \"current\" failed to initialize"});
    if (window.spritesBuffer.target == null) return window.fail({ title: "\"sprite\" buffer is null", message: "spritesBuffer of ket \"target\" failed to initialize"});
    device.queue.writeBuffer(window.spritesBuffer.current, 0, sprites, 0, NO_OF_SPRITES);
    
    sprites[0] = add32Uints(IDK_ONE_SPRITE_IG_AS_TEST, (64 << 25) >>> 0); // comment this once you're done
    device.queue.writeBuffer(window.spritesBuffer.target, 0, sprites, 0, NO_OF_SPRITES);
    
    function createSpritesBufferOfSize(amountOfSprites: number) {
        return device.createBuffer({
            label: "Sprites buffer",
            size: amountOfSprites * 4,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
        });
    }

    function add32Uints(...numbers: number[]) {
        let sum = 0;
        for (let i = 0; i < numbers.length; i++) { sum = (sum + numbers[i]) >>> 0; }
        return sum;
    }
}

export { createBuffers, updateWorldData }