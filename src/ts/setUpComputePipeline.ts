import { setUpGenerateWorld } from "./compute/generateWorldShader";
import { setUpComputeSprites } from "./compute/computeSprites";

async function setUpComputePipelines(parameters: {device: GPUDevice, ctx: GPUCanvasContext}) {
    const { device, ctx } = parameters;

    await setUpGenerateWorld({ device });
    await setUpComputeSprites({ device, ctx });
}

export { setUpComputePipelines }