let device = null;

const global = window.canvasResize = {};
global.setUp = (gpu) => {
    device = gpu.device

    window.viewportUniform = device.createBuffer({
        label: `render world viewport uniform`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });

    resizeCanvas;
    window.onresize = resizeCanvas;
}

function resizeCanvas () {
    // console.log("setting canvas to width:", canvas.clientWidth, "height:", canvas.clientHeight);
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;

    device.queue.writeBuffer(window.viewportUniform, 0, new Float32Array([canvas.width, canvas.height]));
}