const global = window.canvasResize = {};
global.setUp = () => {
    resizeCanvas();
    window.onresize = resizeCanvas;
}

function resizeCanvas () {
    // console.log("setting canvas to width:", canvas.clientWidth, "height:", canvas.clientHeight);
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;

    window.renderWorld.writeViewportBuffer(canvas);
}