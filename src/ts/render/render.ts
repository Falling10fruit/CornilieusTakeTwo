let device: GPUDevice;
let ctx: GPUCanvasContext;
let debug_buffer: GPUBuffer;
let debug_buffer_mapped: GPUBuffer;

import { print_bits } from "../../bit_utils.ts";
import { computeSprites} from "../compute/computeSprites.ts";
import { renderWorld } from "./renderWorld.ts";
import { renderSprites } from "./renderSprites.ts";

/** Sets up the {@link render} function.
 * 
 * Implementation at {@link setUpRender} */
function setUpRender (parameters: { device: GPUDevice, ctx: GPUCanvasContext}) {
    device = parameters.device;
    ctx = parameters.ctx;
}

const debugging_time = false; // debug code commented out because the prject fails silently and I'm not debugging anyways
/** The function that renders the entire frame.
 * 
 * Implementation at {@link render} */
function render () {
    controlCamera(); // comment this out later

    if (window.camera.uniformBuffer == null) { return window.fail({ title: `camera buffer not set`, message: `uniform buffer is null` as string})}

    device.queue.writeBuffer(window.camera.uniformBuffer, 0, new Float32Array([window.camera.xPos, window.camera.yPos, window.camera.scale, window.camera.rotation]));

    const commandEncoder = device.createCommandEncoder({ label: `render command encoder`});
    
    const computePass = commandEncoder.beginComputePass({ label: `render computePass` });
    computeSprites(computePass);
    computePass.end();

    const renderPass = commandEncoder.beginRenderPass({
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

    // if (window.debug.buffer == null)        return window.fail({title: `debug buffer is null`,        message: `debugging render`});
    // if (window.debug.unmapped_buffers == null) return window.fail({title: `debug mapped buffer is null`, message: `debugging render`});
    // let mapping_buffer = null;
    // if (window.debug.unmapped_buffers.length > 0 && debugging_time) {
    //     mapping_buffer = window.debug.unmapped_buffers[0];
    //     window.debug.unmapped_buffers.splice(0, 1);
    // }
    // if (mapping_buffer == null) return;
    // if (debugging_time && window.debug.unmapped_buffers.length > 0) commandEncoder.copyBufferToBuffer(window.debug.buffer, mapping_buffer);

    device.queue.submit([commandEncoder.finish()]);
    
    // if (debugging_time) {
    //     mapping_buffer.mapAsync(GPUMapMode.READ).then(() => {
    //         if (window.debug.unmapped_buffers == null) return window.fail({title: `debug mapped buffer is null`, message: `debug mapped buffer became null after trying to map it for reading whilst debugging rendering`});

    //         // print_bits(0);
    //         // print_bits((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
    //         // console.log((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
    //         console.log((new Float32Array(mapping_buffer.getMappedRange()))[0]);
    //         mapping_buffer.unmap();

    //         window.debug.unmapped_buffers.push(mapping_buffer);
    //     });
    // }

    if (!debugging_time) requestAnimationFrame(render);
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