/* @refresh reload */
import { render } from 'solid-js/web'
import { App, } from './App.tsx'
const root = document.getElementById('root')
if (root) render(App, root);

import track_mouse from './ts/track_mouse.ts'
import { get_gpu } from './ts/get_device.ts';
import { create_gpu_objects } from './ts/initialize.ts';
import { encode_pipelines_to_pass, return_compute_pipelines } from './ts/compute_pipelines.ts';
import { return_render_pipeline, render_grid } from './ts/render.ts';

const canvas = document.getElementById("canvas") as HTMLCanvasElement;
canvas.width = 64 * 3;
canvas.height = 36 * 3;

const { device, ctx } = await get_gpu();
create_gpu_objects(device, ctx);
track_mouse(device);

device.queue.writeBuffer(window.render.viewport_buffer, 0,
    new Float32Array([ ctx.canvas.width, ctx.canvas.height ])
);

var gpu_time_spent:Array<number> = [];

const [render_pipeline, compute_pipelines] = await Promise.all([return_render_pipeline(device), return_compute_pipelines(device)]);


tick();
function tick() {
    const command_encoder = device.createCommandEncoder({ label: `command buffer` });
    
    render_grid(command_encoder, ctx, render_pipeline);

    let query_result_buffer = undefined;
    if (window.compute.timing.mapped_timed_buffers.length > 0) {
        query_result_buffer = window.compute.timing.mapped_timed_buffers[0];
        window.compute.timing.mapped_timed_buffers.splice(0, 1);

        command_encoder.resolveQuerySet(window.compute.timing.query_set, 0, window.compute.timing.query_set.count, window.compute.timing.resolve_buffer, 0);
        command_encoder.copyBufferToBuffer(window.compute.timing.resolve_buffer, 0, query_result_buffer, 0, window.compute.timing.resolve_buffer.size);
    } else {
        console.warn("There aren't any mapped time buffers left, adding more :)");
        window.compute.timing.mapped_timed_buffers.push(device.createBuffer({
            label: "query result buffer",
            size: window.compute.timing.resolve_buffer.size,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
        }));
    }

    if (window.compute.debug.buffer.mapState == "unmapped") { command_encoder.copyBufferToBuffer(window.compute.debug.copied_buffer, window.compute.debug.buffer); }
    if (window.render.frame_buffer.mapState == "unmapped") { command_encoder.copyTextureToBuffer(
        { texture: ctx.getCurrentTexture() },
        {
            buffer: window.render.frame_buffer,
            bytesPerRow: ctx.canvas.width * 4
        }, [ctx.canvas.width, ctx.canvas.height, 1]
    ); }
    
    device.queue.submit([command_encoder.finish()]);

    if (query_result_buffer != undefined) { query_result_buffer.mapAsync(GPUMapMode.READ).then(() => {
        const timestaps = (new BigUint64Array(query_result_buffer.getMappedRange()));
        const new_time = Number(timestaps[1] - timestaps[0]) / 10**3;

        if (gpu_time_spent.length == 20) { gpu_time_spent.splice(0, 1); }
        gpu_time_spent.push(new_time);

        query_result_buffer.unmap();
        window.compute.timing.mapped_timed_buffers.push(query_result_buffer);
    }); }
    

    if (window.compute.debug.buffer.mapState == "unmapped") { window.compute.debug.buffer.mapAsync(GPUMapMode.READ).then(() => {
        const debug_buffer_value = (new Uint32Array(window.compute.debug.buffer.getMappedRange()))[0];

        console.log(debug_buffer_value);
        console.log(debug_buffer_value.toString(16).toUpperCase().padStart(8, "0"));
        console.log((debug_buffer_value.toString(2).padStart(32, "0").match(/.{1,8}/g) || []).join(' '));
    }); }

    requestAnimationFrame(tick)
}