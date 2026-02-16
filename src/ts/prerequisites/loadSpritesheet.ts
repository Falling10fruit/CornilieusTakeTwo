/** Fetches the spritesheet, then creates a texture and sampler to {@link window.spritesheet}
 * 
 * Implementation at
 * @see {@link loadSpritesheet}*/
async function loadSpritesheet (parameters: { device: GPUDevice }) {
    const device = parameters.device;

    const res = await fetch("./src/spritesheet.png");
    const blob = await res.blob();
    const spritesheetSource = await createImageBitmap(blob, { colorSpaceConversion: "none" });

    window.spritesheet = {
        texture: device.createTexture({
            label: "spritesheet texture",
            format: "rgba8unorm",
            size: [spritesheetSource.width, spritesheetSource.height],
            usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
        }),
        sampler: device.createSampler(),
    };

    if (window.spritesheet.texture == null) return window.fail({title: "Failed to generate spritesheet texture", message: "idfk we just made it recently"});
    device.queue.copyExternalImageToTexture(
        { source: spritesheetSource, flipY: false },
        { texture: window.spritesheet.texture },
        spritesheetSource // width, height
    );
}

export { loadSpritesheet }