import { setUpGPU } from "./ts/prerequisites/setUpGPU";
import { preload } from "./preload";
import { setUpComputePipelines } from "./ts/setUpComputePipeline";
import { setUpRenderPipelines } from "./ts/setUpRenderPipelines";
import { generateWorldToBuffer } from "./ts/compute/generateWorldShader";

import { render } from "./ts/render/render";
import { bufferInput } from "./ts/compute/playerInput";

const { device, ctx } = await setUpGPU();

await preload({ device: device });
Promise.all([
    setUpComputePipelines({ device, ctx }),
    setUpRenderPipelines({ device, ctx })
]).then(() => {
    createPrerequisiteVariables().then(start);
});

async function createPrerequisiteVariables() {
    if (window.world.storageBuffer == null) return console.error("World storage buffer is null");
    await generateWorldToBuffer({...window.world});
}

function start() {
    bufferInput(device);

    render(); // Also kickstart the simulation here eventually idk when, hopefully soon
}