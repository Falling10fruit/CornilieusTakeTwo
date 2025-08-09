resizeCanvas();
window.onresize = resizeCanvas;

render(); // render and gametick are not synced
function render () {
    controlCamera();

    window.gl.clearColor(0, 0, 0, 0);
    window.gl.clear(window.gl.COLOR_BUFFER_BIT);

    window.renderWorld();

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

function resizeCanvas () {
    // console.log("setting canvas to width:", canvas.clientWidth, "height:", canvas.clientHeight);
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;
    window.gl.viewport(0, 0, window.gl.canvas.width, window.gl.canvas.height);

    window.updateWorldRenderViewport(canvas.width, canvas.height);
}