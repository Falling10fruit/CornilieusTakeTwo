let device: GPUDevice;

/** Sets up the handler to resize the canvas when the window resizes. */
function setUpCanvasResize (parameters: { device: GPUDevice }) {
    device = parameters.device;

    window.viewportUniform = device.createBuffer({
        label: `render world viewport uniform`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });

    resizeCanvas();
    window.onresize = resizeCanvas;
}

const canvas = document.getElementById("canvas") as HTMLCanvasElement;

/**`window.onwindowresize` handler. 
 * 
 * This function will write to the viewport uniform buffer. */
function resizeCanvas () {
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;
    
    if (window.viewportUniform == null) return console.log("huh, why isn't the viewport initialized");
    device.queue.writeBuffer(window.viewportUniform, 0, new Float32Array([canvas.width, canvas.height]));
}
    
export { setUpCanvasResize, resizeCanvas }