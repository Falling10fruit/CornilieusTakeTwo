/** Create the WebGPU device and context.
 * @async
 * 
 * Implementation at {@link get_device}.ts*/
async function get_device () {
    if (!navigator.gpu) { console.error({
        title: "WebGPU is not supported in this browser",
        message: "you should never see this error"
    }) }

    const adapter = await navigator.gpu?.requestAdapter() as GPUAdapter;
    if (!adapter) { console.error({
        title: "Unable to request adapter",
        message: "your device does not support WebGPU"
    }) }

    const device = await adapter.requestDevice({
        requiredLimits: {
            maxStorageBuffersPerShaderStage: 12,
        },
        requiredFeatures: [
            "timestamp-query",
            "subgroups"
        ]
    });
    device.lost.then((e) => {
        console.error({
            title: "WebGPU device lost",
            message: e.message
        });

        if (e.reason !== "destroyed") get_device();
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

export { get_device }