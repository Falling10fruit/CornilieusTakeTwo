/** Create the WebGPU device and context.
 * @async
 * 
 * Implementation at {@link setUpGPU}.ts*/
async function setUpGPU () {
    if (!navigator.gpu) { window.fail({
        title: "WebGPU is not supported in this browser",
        message: "you should never see this error"
    }) }

    const adapter = await navigator.gpu?.requestAdapter() as GPUAdapter;
    if (!adapter) { window.fail({
        title: "Unable to request adapter",
        message: "your device does not support WebGPU"
    }) }

    const device = await adapter.requestDevice({
        requiredLimits: {
            maxStorageBuffersPerShaderStage: 12,
        }
    });
    device.lost.then((e) => {
        window.fail({
            title: "WebGPU device lost",
            message: e.message
        });

        if (e.reason !== "destroyed") setUpGPU();
    });

    const ctx = (document.getElementById("canvas") as HTMLCanvasElement)
        .getContext("webgpu") as GPUCanvasContext;
    ctx.configure({
        device: device,
        format: navigator.gpu.getPreferredCanvasFormat(),
        alphaMode: "premultiplied",
    });

    return { device, ctx };
};

export { setUpGPU }