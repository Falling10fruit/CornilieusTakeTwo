import { setUpCanvasResize } from "./prerequisites/canvasResize.ts"
import { loadSpritesheet } from "./prerequisites/loadSpritesheet.ts";
import { setUpRenderWorld } from "./render/renderWorld.ts";
import { setUpRenderSprites } from "./render/renderSprites.ts";
import { setUpRender } from "./render/render.ts";

async function setUpRenderPipelines(parameters: { device: GPUDevice, ctx: GPUCanvasContext }) {
    const { device, ctx } = parameters;

    await setUpCanvasResize({ device });
    await loadSpritesheet({ device });
    await setUpRender({ device, ctx });
    await setUpRenderWorld({ device });
    await setUpRenderSprites({ device });
}

export { setUpRenderPipelines }