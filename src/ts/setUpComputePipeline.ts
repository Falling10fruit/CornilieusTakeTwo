import { setUpGenerateWorld } from "./generateWorldShader";


async function setUpComputePipelines(parameters: {device: GPUDevice, ctx: GPUCanvasContext}) {
    const { device, ctx } = parameters;

    await setUpGenerateWorld({ device });
}

export { setUpComputePipelines }