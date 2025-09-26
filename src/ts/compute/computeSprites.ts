let device: GPUDevice;
let ctx: GPUCanvasContext;

async function setUpComputeSprites(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    ctx = parameters.ctx;

    const sprites = new Uint32Array(2**24);

    const IDK_ONE_SPRITE_IG_AS_TEST  = add32Uints(
        ( 0 << 25 ) >>> 0,
        ( 3 << 18 ) >>> 0,
        ( 0  << 9 ) >>> 0,
        ( 1  << 0 ) >>> 0
    ) >>> 0;
    sprites[0] = IDK_ONE_SPRITE_IG_AS_TEST;
    console.log(IDK_ONE_SPRITE_IG_AS_TEST);

    window.spritesBuffer = device.createBuffer({
        label: "Sprites buffer",
        size: 2**24 * 4, // a u32 for each of the 16777216 sprites, should be more actually to accomodate for both entities and particles
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    })
    device.queue.writeBuffer(window.spritesBuffer,
        0,
        sprites,
        0,
        2**24 // idk how env variables work
    );

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
}

function add32Uints(...numbers: number[]) {
    let sum = 0;
    for (let i = 0; i < numbers.length; i++) { sum = (sum + numbers[i]) >>> 0; }
    return sum;
}

export { setUpComputeSprites }