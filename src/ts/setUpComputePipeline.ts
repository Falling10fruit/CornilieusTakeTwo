import { setUpGenerateWorld } from "./compute/generateWorldShader";
import { setUpComputeSprites } from "./compute/computeSprites";
import { setUpComputeEntities } from "./compute/computeEntities";
import { setUpComputeInputs } from "./compute/playerInput";

async function setUpComputePipelines(parameters: {device: GPUDevice, ctx: GPUCanvasContext}) {
    const { device, ctx } = parameters;

    await setUpGenerateWorld({ device });
    await setUpComputeSprites({ device, ctx });
    await setUpComputeEntities({ device, ctx });
    await setUpComputeInputs({ device, ctx });
}

export { setUpComputePipelines }