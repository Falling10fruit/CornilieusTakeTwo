import { setUpGPU } from "./ts/prerequisites/setUpGPU";
import { preload } from "./preload";

import { setUpGenerateWorld } from "./ts/compute/generateWorldShader";
import { setUpComputeSprites } from "./ts/compute/computeSprites";
import { setUpComputeEntities } from "./ts/compute/computeEntities";
import { setUpComputeInputs } from "./ts/compute/playerInput";
import { setUpCanvasResize } from "./ts/prerequisites/canvasResize.ts"
import { setUpRenderWorld } from "./ts/render/renderWorld.ts";
import { setUpRenderSprites } from "./ts/render/renderSprites.ts";
import { setUpRender } from "./ts/render/render.ts";

import { generateWorldToBuffer } from "./ts/compute/generateWorldShader";

import { createPlaceholderEntities } from "./ts/compute/computeEntities";

import { render } from "./ts/render/render";
import { compute, setUpComputePass } from "./ts/compute/compute";

const { device, ctx } = await setUpGPU();
await preload({ device: device });

Promise.all([
    setUpComputePass({ device }),
    setUpRender({ device, ctx }),
    setUpGenerateWorld({ device }),
    setUpComputeSprites({ device, ctx }),
    setUpComputeEntities({ device, ctx }),
    setUpComputeInputs({ device, ctx }),
    setUpCanvasResize({ device }),
    setUpRenderWorld({ device }),
    setUpRenderSprites({ device }),
]).then(() => {
    createPrerequisiteVariables().then(start);
});

async function createPrerequisiteVariables() {
    if (window.world.storageBuffer == null) return console.error("World storage buffer is null");
    await generateWorldToBuffer({...window.world});
    await createPlaceholderEntities();
}

async function start() {
    compute();
    render();
}