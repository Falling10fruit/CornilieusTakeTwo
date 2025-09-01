let device = undefined;
let ctx = undefined;

window.setUpRender = (input) => {
    device = input.device;
    ctx = input.ctx;

    window.render = render;
}

function render () {
    controlCamera(); // comment this out later

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
    if (window.keyIsDown.w) window.camera.y += 30*window.camera.zoom;
    if (window.keyIsDown.s) window.camera.y -= 30*window.camera.zoom;
    if (window.keyIsDown.a) window.camera.x -= 30*window.camera.zoom;
    if (window.keyIsDown.d) window.camera.x += 30*window.camera.zoom;
    if (window.keyIsDown.e) window.camera.zoom *= 1.02;
    if (window.keyIsDown.q) window.camera.zoom *= 0.98;
    if (window.keyIsDown.ArrowLeft) window.camera.rotation += Math.PI/180;
    if (window.keyIsDown.ArrowRight) window.camera.rotation -= Math.PI/180;
}