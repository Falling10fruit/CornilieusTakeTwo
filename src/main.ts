import { setUpGPU } from "./ts/prerequisites/setUpGPU";
import { setUpRenderPipelines } from "./ts/setUpRenderPipelines";
import { generateWorldStorageBuffer, generateWorldToBuffer } from "./ts/generateWorldShader";

import { bindWorldStorageBuffer } from "./ts/render/renderWorld";
import { render } from "./ts/render/render";

const { device, ctx } = await setUpGPU();

Promise.all([
    
    setUpRenderPipelines({ device, ctx })
]).then(() => {
    createPrerequisiteVariables().then(start);
});

async function createPrerequisiteVariables() {
    window.world.storageBuffer = await generateWorldStorageBuffer(window.world); // probably remove this and implement it in the main script later
    await generateWorldToBuffer({...window.world, worldBuffer: window.world.storageBuffer});
    await bindWorldStorageBuffer({...window.world, worldBuffer: window.world.storageBuffer});
}

function start() {
    render(); // Also kickstart the simulation here eventually idk when, hopefully soon
}