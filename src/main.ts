import { render } from "solid-js/web";
import { App } from "./index.tsx";
const root = document.getElementById("root")
if (root) render(App, root);

import { setUpGPU } from "./ts/prerequisites/setUpGPU";
import { preload } from "./preload";

import { setUpGenerateWorld } from "./ts/compute/generateWorldShader";
import { createPlaceholderSprites, setUpComputeSprites } from "./ts/compute/computeSprites";
import { setUpComputeEntities } from "./ts/compute/computeEntities";
import { setUpComputeInputs } from "./ts/compute/playerInput";
import { setUpCanvasResize } from "./ts/prerequisites/canvasResize.ts"
import { setUpRenderWorld } from "./ts/render/renderWorld.ts";
import { setUpRenderSprites } from "./ts/render/renderSprites.ts";
import { setUpRender } from "./ts/render/render.ts";

import { generateWorldToBuffer } from "./ts/compute/generateWorldShader";

import { createPlaceholderEntities } from "./ts/compute/computeEntities";

import { draw } from "./ts/render/render"; //
import { compute, setUpComputePass } from "./ts/compute/compute";

const { device, ctx } = await setUpGPU();

await preload({ device: device });

await Promise.all([
    setUpComputePass({ device }),
    setUpRender({ device, ctx }),
    setUpGenerateWorld({ device }),
    setUpComputeSprites({ device, ctx }),
    setUpComputeEntities({ device, ctx }),
    setUpComputeInputs({ device, ctx }),
    setUpCanvasResize({ device }),
    setUpRenderWorld({ device }),
    setUpRenderSprites({ device }),
]);

await Promise.all([
    generateWorldToBuffer(),
    createPlaceholderEntities(),
    createPlaceholderSprites()
]);

compute();
draw();