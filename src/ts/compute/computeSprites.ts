let device: GPUDevice;
let ctx: GPUCanvasContext;

async function setUpComputeSprites(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    device = parameters.device;
    ctx = parameters.ctx;

    const IDK_ONE_SPRITE_IG_AS_TEST = new Uint32Array(2**24);
    IDK_ONE_SPRITE_IG_AS_TEST[0] =
        ( 64  << 25 ) + 
        ( 64  << 18 ) +
        ( 128 << 9  ) +
        ( 1   << 0  )  ;

    window.spritesBuffer = device.createBuffer({
        label: "Sprites buffer",
        size: 2**24 * 4, // a u32 for each of the 16777216 sprites, should be more actually to accomodate for both entities and particles
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC
    })
    device.queue.writeBuffer(window.spritesBuffer,
        0,
        IDK_ONE_SPRITE_IG_AS_TEST,
        0,
        2**24 // idk how env variables work
    )
}

export { setUpComputeSprites }