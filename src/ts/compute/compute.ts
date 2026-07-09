import { bufferInput, computeInputs, uploadInput } from "./playerInput";
import { computeEntities } from "./computeEntities";
import { print_bits } from "../../bit_utils";

let device: GPUDevice;
let command_buffer: GPUCommandBuffer; // In prod, we still need to change the buffer for loading in 

function setUpComputePass (parameters: { device: GPUDevice}) {
    device = parameters.device;
}

const debugging_time = false;
let debugging_loops = 999999999;
function compute() {
    // if (debugging_time) window.keyIsDown["w"] = true;
    
    uploadInput();
    bufferInput();
    
    const commandEncoder = device.createCommandEncoder({ label: `compute command encoder` });

    const computePass = commandEncoder.beginComputePass({ label: `compute pass`});
    computeInputs(computePass);
    computeEntities(computePass);
    computePass.end();
    
    if (debugging_time) {
        if (window.debug.buffer == null)        return window.fail({title: `debug buffer is null`,        message: `debugging entities`});
        if (window.debug.unmapped_buffers == null) return window.fail({title: `debug unmapped buffers is null`, message: `debugging entities`});
        let mapping_buffer = null;
        if (window.debug.unmapped_buffers.length > 0) {
            mapping_buffer = window.debug.unmapped_buffers[0];
            window.debug.unmapped_buffers.splice(0, 1);
        }
        if (mapping_buffer == null) return;
        if (mapping_buffer != null && window.debug.unmapped_buffers.length > 0) commandEncoder.copyBufferToBuffer(window.debug.buffer, mapping_buffer);
        
        device.queue.submit([commandEncoder.finish()]);
    
        if (mapping_buffer != null && window.debug.unmapped_buffers.length > 0) {
            mapping_buffer.mapAsync(GPUMapMode.READ).then(function () {
                if (window.debug.unmapped_buffers == null) return window.fail({title: `debug unmapped buffers is null`, message: `debug unmapped buffers became null after trying to map it for reading whilst debugging entities`});
    
                // console.log(`debug reference`)
                // print_bits(8388802);
                // console.log("debug buffer");
                // print_bits((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
                // console.log((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
                console.log((new Float32Array(mapping_buffer.getMappedRange()))[0]);
                // console.log((new Int32Array(mapping_buffer.getMappedRange()))[0]);
                mapping_buffer.unmap();
                
                window.debug.unmapped_buffers.push(mapping_buffer);
            });
        }

        
    } else {
        device.queue.submit([commandEncoder.finish()]);
    }
    
    if (debugging_loops > 0 || !debugging_time) {
        debugging_loops--;
        window.world.entities.current_entity_buffer_is = (window.world.entities.current_entity_buffer_is == 0) ? 1 : 0;
        requestAnimationFrame(compute) // eventually transfer to webworkers
    };
}

export { setUpComputePass, compute}