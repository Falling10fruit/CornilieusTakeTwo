// const global = window.loadSpritesheet = {}; I don't think we'll have any other methods
const res = await fetch("./src/spritesheet.png");
const blob = await res.blob();
const spritesheetSource = await createImageBitmap(blob, { colorSpaceConversion: "none" });

/** Fetches the spritesheet, then creates a texture and sampler to {@link window.spritesheet}
 * 
 * Implementation at
 * @see {@link loadSpritesheet}*/
async function loadSpritesheet (parameters: { device: GPUDevice }) {
    const device = parameters.device;

    window.spritesheet = {
        texture: device.createTexture({
            label: "spritesheet texture",
            format: "rgba8unorm",
            size: [spritesheetSource.width, spritesheetSource.height],
            usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
        }),
        sampler: device.createSampler(),
    };

    device.queue.copyExternalImageToTexture(
        { source: spritesheetSource, flipY: true },
        { texture: window.spritesheet.texture as GPUTexture },
        spritesheetSource // width, height
    );
}

export { loadSpritesheet }