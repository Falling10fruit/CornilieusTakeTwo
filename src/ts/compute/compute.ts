import { computeInputs } from "./playerInput";
import { computeEntities } from "./computeEntities";

let device: GPUDevice;

function setUpComputePass (parameters: { device: GPUDevice}) {
    device = parameters.device;
}

const debugging_time = false;
let debugging_loops = 1;

function compute() {
    const commandEncoder = device.createCommandEncoder({ label: `compute entities command encoder` });

    const computePass = commandEncoder.beginComputePass({ label: `compute entities compute pass`});
    computeInputs(computePass);
    computeEntities(computePass);
    computePass.end();
    
    if (window.debug.buffer == null)        return window.fail({title: `debug buffer is null`,        message: `debugging entities`});
    if (window.debug.unmapped_buffers == null) return window.fail({title: `debug unmapped buffers is null`, message: `debugging entities`});
    let mapping_buffer = null;
    if (window.debug.unmapped_buffers.length > 0 && debugging_time) {
        mapping_buffer = window.debug.unmapped_buffers[0];
        window.debug.unmapped_buffers.splice(0, 1);
    }
    if (mapping_buffer == null && debugging_time) return;
    if (mapping_buffer != null && debugging_time && window.debug.unmapped_buffers.length > 0) commandEncoder.copyBufferToBuffer(window.debug.buffer, mapping_buffer);
    
    device.queue.submit([commandEncoder.finish()]);

    if (mapping_buffer != null && debugging_time && window.debug.unmapped_buffers.length > 0) {
        mapping_buffer.mapAsync(GPUMapMode.READ).then(function () {
            if (window.debug.unmapped_buffers == null) return window.fail({title: `debug unmapped buffers is null`, message: `debug unmapped buffers became null after trying to map it for reading whilst debugging entities`});

            // console.log(`debug reference`)
            // print_bits(8388802);
            console.log("debug buffer");
            // print_bits((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
            console.log((new Uint32Array(mapping_buffer.getMappedRange()))[0]);
            // console.log((new Float32Array(mapping_buffer.getMappedRange()))[0]);
            // console.log((new Int32Array(mapping_buffer.getMappedRange()))[0]);
            mapping_buffer.unmap();
            
            window.debug.unmapped_buffers.push(mapping_buffer);
        });
    }

    if (!debugging_time || debugging_loops > 0) {
        if (debugging_time) debugging_loops--;
        window.entitiesBuffer.current_entity_buffer_is = (window.entitiesBuffer.current_entity_buffer_is == 0) ? 1 : 0;
        requestAnimationFrame(compute) // eventually transfer to webworkers
    };
}

export { setUpComputePass, compute}