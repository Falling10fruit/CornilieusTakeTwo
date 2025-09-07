// const global = window.loadSpritesheet = {}; I don't think we'll have any other methods
const res = await fetch("../../spritesheet.png");
const blob = await res.blob();
const spritesheetSource = await createImageBitmap(blob, { colorSpaceConversion: "none" });

window.loadSpritesheet = async ({ device }) => {
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
        { texture: window.spritesheet.texture },
        spritesheetSource // width, height
    );
}