/** Create the WebGPU device and context.
 * @async
 * 
 * Implementation at {@link get_gpu}.ts*/
async function get_gpu () {
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
        requiredFeatures: [
            "timestamp-query"
        ]
    });
    device.lost.then((e) => {
        console.error({
            title: "WebGPU device lost",
            message: e.message
        });

        if (e.reason !== "destroyed") get_gpu();
    });

    const ctx = (document.getElementById("canvas") as HTMLCanvasElement)
        .getContext("webgpu") as GPUCanvasContext;
    ctx.configure({
        device: device,
        format: navigator.gpu.getPreferredCanvasFormat(),
        alphaMode: "premultiplied",
        usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC
    });

    return { device, ctx };
};

export { get_gpu }