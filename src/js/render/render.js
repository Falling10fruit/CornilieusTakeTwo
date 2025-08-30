window.render = ({ device, renderPassDescriptor}) => { // Yes I am replacing the function
    controlCamera(); // comment this out later

    const commanderEncoder = device.createCommandEncoder({ label: `render world command encoder`});
    const pass = commanderEncoder.beginRenderPass(renderPassDescriptor);

    window.renderWorld(pass);

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