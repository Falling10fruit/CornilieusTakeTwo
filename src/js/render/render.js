let device = undefined;
let ctx = undefined;

window.setUpRender = (input) => {
    device = input.device;
    ctx = input.ctx;

    window.camera.transformUniform = device.createBuffer({
        label: `camera tranform uniform`,
        size: 2 * 4 + // vec2
              1 * 4 + // f32
              1 * 4 + // f32
              0 * 4 , // + padding
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });

    window.render = render;
}

function render () {
    controlCamera(); // comment this out later
    device.queue.writeBuffer(window.camera.transformUniform, 0, new Float32Array([window.camera.xPos, window.camera.yPos, window.camera.scale, window.camera.rotation]));

    const commanderEncoder = device.createCommandEncoder({ label: `render command encoder`});
    const pass = commanderEncoder.beginRenderPass({
        label: `render pass`,
        colorAttachments: [{
            clearValue: [0.19607843137254902, 0.39215686274509803, 0.0, 1.0],
            loadOp: `clear`,
            storeOp: `store`,
            view: ctx.getCurrentTexture().createView(),
        }],
    });

    window.renderWorld.render(pass);

    pass.end();
    device.queue.submit([commanderEncoder.finish()]);

    requestAnimationFrame(render);
}

function controlCamera() {
    if (window.keyIsDown.w) window.camera.yPos += 10 / window.camera.scale;
    if (window.keyIsDown.s) window.camera.yPos -= 10 / window.camera.scale;
    if (window.keyIsDown.a) window.camera.xPos -= 10 / window.camera.scale;
    if (window.keyIsDown.d) window.camera.xPos += 10 / window.camera.scale;
    if (window.keyIsDown.e) window.camera.scale *= 1.02;
    if (window.keyIsDown.q) window.camera.scale *= 0.98;
    if (window.keyIsDown.ArrowLeft) window.camera.rotation += Math.PI/180;
    if (window.keyIsDown.ArrowRight) window.camera.rotation -= Math.PI/180;
}