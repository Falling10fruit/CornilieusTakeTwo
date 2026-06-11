import { invoke } from "@tauri-apps/api/core";

async function load_spritesheet () {
    const bytes = new Uint8Array(await invoke("get_spritesheet")) as BlobPart;
    const blob = new Blob([bytes], { type: "image/png" });

    return new Promise((res, rej) => {
        const img = new Image();

        img.onload = () => res(img);
        img.onerror = (err) => rej(err);
        img.src = URL.createObjectURL(blob);
    })
}

/** Fetches the spritesheet, then creates a texture and sampler to {@link window.spritesheet}
 * 
 * Implementation at
 * @see {@link loadSpritesheet}*/
async function loadSpritesheet (parameters: { device: GPUDevice }) {
    const device = parameters.device;

    try {
        const spritesheetSource = await load_spritesheet() as HTMLImageElement; 

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
    } catch (error) {
        return window.fail({ title: "Failed to load spritesheet", message: error });
    }
}

export { loadSpritesheet }