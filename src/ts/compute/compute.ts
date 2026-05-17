import { bufferInput, computeInputs, uploadInput } from "./playerInput";
import { computeEntities } from "./computeEntities";
import { print_bits } from "../../bit_utils";

let device: GPUDevice;
let command_buffer: GPUCommandBuffer; // In prod, we still need to change the buffer for loading in 

function setUpComputePass (parameters: { device: GPUDevice}) {
    device = parameters.device;
    

    const commandEncoder = device.createCommandEncoder({ label: `compute command encoder` });

    const computePass = commandEncoder.beginComputePass({ label: `compute pass`});
    computeInputs(computePass);
    computeEntities(computePass);
    computePass.end();

    command_buffer = commandEncoder.finish();
}

const debugging_time = false;
let debugging_loops = 999999999;
function compute() {
    // if (debugging_time) window.keyIsDown["w"] = true;
    
    uploadInput();
    bufferInput();

    if (!debugging_time) {
        device.queue.submit([command_buffer]);
        requestAnimationFrame(compute) // eventually transfer to webworkers
    } else {
        const command_debug_encoder = device.createCommandEncoder({ label: `compute debug command encoder` });
        
        if (window.debug.buffer == null)        return window.fail({title: `debug buffer is null`,        message: `debugging entities`});
        if (window.debug.unmapped_buffers == null) return window.fail({title: `debug unmapped buffers is null`, message: `debugging entities`});
        let mapping_buffer = null;
        if (window.debug.unmapped_buffers.length > 0) {
            mapping_buffer = window.debug.unmapped_buffers[0];
            window.debug.unmapped_buffers.splice(0, 1);
        }
        if (mapping_buffer == null) return;
        if (mapping_buffer != null && window.debug.unmapped_buffers.length > 0) command_debug_encoder.copyBufferToBuffer(window.debug.buffer, mapping_buffer);
        
        device.queue.submit([command_buffer, command_debug_encoder.finish()]);

        if (mapping_buffer != null && window.debug.unmapped_buffers.length > 0) {
            mapping_buffer.mapAsync(GPUMapMode.READ).then(function () {
                if (window.debug.unmapped_buffers == null) return window.fail({title: `debug unmapped buffers is null`, message: `debug unmapped buffers became null after trying to map it for reading whilst debugging entities`});

                // console.log(`debug reference`)
                // print_bits(8388802);
                // console.log("debug buffer");
                // print_bits((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
                console.log((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
                // console.log((new Float32Array(mapping_buffer.getMappedRange()))[0]);
                // console.log((new Int32Array(mapping_buffer.getMappedRange()))[0]);
                mapping_buffer.unmap();
                
                window.debug.unmapped_buffers.push(mapping_buffer);
            });
        }
        
        if (debugging_loops > 0) {
            debugging_loops--;
            window.world.entities.current_entity_buffer_is = (window.world.entities.current_entity_buffer_is == 0) ? 1 : 0;
            requestAnimationFrame(compute) // eventually transfer to webworkers
        };
    }   
}

export { setUpComputePass, compute}