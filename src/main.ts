import { setUpGPU } from "./ts/prerequisites/setUpGPU";
import { setUpComputePipelines } from "./ts/setUpComputePipeline";
import { setUpRenderPipelines } from "./ts/setUpRenderPipelines";
import { generateWorldToBuffer } from "./ts/compute/generateWorldShader";

import { bindWorldStorageBuffer } from "./ts/render/renderWorld";
import { render } from "./ts/render/render";

const { device, ctx } = await setUpGPU();

Promise.all([
    setUpComputePipelines({ device, ctx }),
    setUpRenderPipelines({ device, ctx })
]).then(() => {
    createPrerequisiteVariables().then(start);
});

async function createPrerequisiteVariables() {
    if (window.world.storageBuffer == null) return console.error("World storage buffer is null");
    bindWorldStorageBuffer({...window.world, worldBuffer: window.world.storageBuffer});
    await generateWorldToBuffer({...window.world, worldBuffer: window.world.storageBuffer});
}

function start() {
    render(); // Also kickstart the simulation here eventually idk when, hopefully soon
}