window.setUpGPU = async function () {
    if (!navigator.gpu) { window.fail({
        title: "WebGPU is not supported in this browser",
        message: "you should never see this error"
    }) }

    const adapter = await navigator.gpu?.requestAdapter();
    if (!adapter) { window.fail({
        title: "Unable to request adapter",
        message: "your device does not support WebGPU"
    }) }

    const device = await adapter.requestDevice();
    device.lost.then((e) => {
        window.fail({
            title: "WebGPU device lost",
            message: e.message
        });

        if (e.reason !== "destroyed") setUpGPU();
    });

    const ctx = document.getElementById("canvas").getContext("webgpu", { alpha: `premultiplied` });
    ctx.configure({
        device: device,
        format: navigator.gpu.getPreferredCanvasFormat()
    });

    return { device, ctx };
};

setUpGPU();