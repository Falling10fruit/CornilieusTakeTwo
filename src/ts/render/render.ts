let device: GPUDevice;
let ctx: GPUCanvasContext;

import { computeSprites } from "../compute/computeSprites.ts";
import { renderWorld } from "./renderWorld.ts";
import { renderSprites } from "./renderSprites.ts";

/** Sets up the {@link render} function.
 * 
 * Implementation at {@link setUpRender} */
function setUpRender (parameters: { device: GPUDevice, ctx: GPUCanvasContext}) {
    device = parameters.device;
    ctx = parameters.ctx;
}


/** The function that renders the entire frame.
 * 
 * Implementation at {@link render} */
function render () {
    controlCamera(); // comment this out later

    if (window.camera.uniformBuffer == null) { return window.fail({ title: `camera buffer not set`, message: `uniform buffer is null` as string})}

    device.queue.writeBuffer(window.camera.uniformBuffer, 0, new Float32Array([window.camera.xPos, window.camera.yPos, window.camera.scale, window.camera.rotation]));

    const commanderEncoder = device.createCommandEncoder({ label: `render command encoder`});
    
    const computePass = commanderEncoder.beginComputePass({ label: `render computePass` });
    computeSprites(computePass);
    computePass.end();

    const renderPass = commanderEncoder.beginRenderPass({
        label: `render renderPass`,
        colorAttachments: [{
            clearValue: [0.19607843137254902, 0.39215686274509803, 0.0, 1.0],
            loadOp: `clear`,
            storeOp: `store`,
            view: ctx.getCurrentTexture().createView(),
        }],
    });
    renderWorld(renderPass);
    renderSprites(renderPass);
    renderPass.end();

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

export { setUpRender, render }