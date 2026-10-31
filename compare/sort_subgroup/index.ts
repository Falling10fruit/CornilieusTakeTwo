/* @refresh reload */
import { render } from 'solid-js/web'
import App from './App.tsx'
const root = document.getElementById('root')
if (root) render(App, root);

import { get_gpu } from './ts/get_device.ts';
import { create_gpu_objects } from './ts/initialize.ts';
import { encode_pipelines_to_pass, return_pipelines } from './ts/compute_pipelines.ts';

const canvas = document.getElementById("canvas") as HTMLCanvasElement;
canvas.width = 64 * 3;
canvas.height = 36 * 3;

window.ENTITY_COUNT_LOG2 = 21;  // only down to 20
const { device, ctx } = await get_gpu();
create_gpu_objects(device, ctx);

device.queue.writeBuffer(window.gpu.render.viewport_buffer, 0,
    new Float32Array([ ctx.canvas.width, ctx.canvas.height ])
);

device.queue.writeBuffer(window.gpu.entity.buffer_0, 0, new Uint32Array([
    (1 << 23) + (1 << 7), 0, 0, 0,
    (1 << 23) + (2 << 7), 0, 0, 0,
    (1 << 23) + (3 << 7), 0, 0, 0,
    (1 << 23) + (4 << 7), 0, 0, 0,
    (1 << 23) + (5 << 7), 0, 0, 0,
    (1 << 23) + (6 << 7), 0, 0, 0,
    (1 << 23) + (7 << 7), 0, 0, 0,
    (1 << 23) + (17 << 7), 0, 0, 0,
    (1 << 23) + (35 << 7), 0, 0, 0,
]));

var gpu_time_spent:Array<number>;

const pipelines = await return_pipelines(device);

let eyedropper_x = 0, eyedropper_y = 0;
let mouse_x = 0, mouse_y = 0, mouse_down = false;
window.onmousedown = (e) => { mouse_down = true; }; window.onmouseup = (e) => { mouse_down = false; };
window.onmousemove = (e) => {
    mouse_x = e.clientX - 5; mouse_y = e.clientY - 5;
    
    if (!mouse_down) return;

    if (mouse_x < ctx.canvas.width && mouse_x >= 0) { eyedropper_x = mouse_x; }
    if (mouse_y < ctx.canvas.height && mouse_y >= 0) { eyedropper_y = mouse_y; }
    update_eyedropper_pointer();
};
const eyedropper_pointer = document.getElementById("eyedropper_pointer");
window.onkeydown = (e) => {
    console.log(e.key);
    if (e.key == "ArrowUp") eyedropper_y = Math.max(0, Math.min(eyedropper_y - 1, ctx.canvas.height - 1));
    if (e.key == "ArrowDown") eyedropper_y = Math.max(0, Math.min(eyedropper_y + 1, ctx.canvas.height - 1));
    if (e.key == "ArrowLeft") eyedropper_x = Math.max(0, Math.min(eyedropper_x - 1, ctx.canvas.width - 1));
    if (e.key == "ArrowRight") eyedropper_x = Math.max(0, Math.min(eyedropper_x + 1, ctx.canvas.width - 1));

    update_eyedropper_pointer();
};
const eyedropper_p = document.getElementById("eyedropper");
let frame_buffer_data: Uint8Array;

const use_interval = true;
if (use_interval) {
    setInterval(tick, 200);
} else { tick(); }
function tick() {
    const command_encoder = device.createCommandEncoder({ label: `command buffer` });
    
    const compute_pass = command_encoder.beginComputePass({
        label: `compute pass`,
        timestampWrites: {
            querySet: window.gpu.timing.query_set,
            beginningOfPassWriteIndex: 0,
            endOfPassWriteIndex: 1
        }
    });
    encode_pipelines_to_pass(device, pipelines, compute_pass)
    compute_pass.end();

    const render_pass = command_encoder.beginRenderPass({
        label: "render pass",
        colorAttachments: [{
            clearValue: [0.0, 0.0, 0.0, 1.0],
            loadOp: `clear`,
            storeOp: `store`,
            view: ctx.getCurrentTexture().createView(),
        }]
    });
    render_pass.setPipeline(render_buffer_pipeline);
    render_pass.setBindGroup(0, render_buffer_bind_group);
    render_pass.draw(3);
    render_pass.end();

    let query_result_buffer = undefined;
    if (mapped_timed_buffers.length > 0) {
        query_result_buffer = mapped_timed_buffers[0];
        mapped_timed_buffers.splice(0, 1);

        command_encoder.resolveQuerySet(query_set, 0, query_set.count, resolve_buffer, 0);
        command_encoder.copyBufferToBuffer(resolve_buffer, 0, query_result_buffer, 0, resolve_buffer.size);
    } else {
        console.warn("There aren't any mapped time buffers left, adding more :)");
        mapped_timed_buffers.push(device.createBuffer({
            label: "query result buffer",
            size: resolve_buffer.size,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
        }));
    }

    if (debug_buffer.mapState == "unmapped") { command_encoder.copyBufferToBuffer(gpu_debug_buffer, debug_buffer); }
    if (frame_buffer.mapState == "unmapped") { command_encoder.copyTextureToBuffer(
        { texture: ctx.getCurrentTexture() },
        {
            buffer: frame_buffer,
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
        mapped_timed_buffers.push(query_result_buffer);
    }); }
    

    if (debug_buffer.mapState == "unmapped") { debug_buffer.mapAsync(GPUMapMode.READ).then(() => {
        const debug_buffer_value = (new Uint32Array(debug_buffer.getMappedRange()))[0];

        console.log(debug_buffer_value);
        console.log(debug_buffer_value.toString(16).toString(16).toUpperCase().padStart(8, "0"));
        console.log((debug_buffer_value.toString(2).padStart(32, "0").match(/.{1,8}/g) || []).join(' '));
    }); }

    if (frame_buffer.mapState == "unmapped") { frame_buffer.mapAsync(GPUMapMode.READ).then(() => {
        frame_buffer_data = new Uint8Array(frame_buffer.getMappedRange());
    }); }
    if (frame_buffer_data != undefined) { eyedropper(); }

    if (!use_interval) { requestAnimationFrame(tick) }
}

function eyedropper() {
    const pixel_index = eyedropper_x + eyedropper_y * ctx.canvas.width;
    const array_index = pixel_index * 4;
    const u32_pixel = (
        (frame_buffer_data[array_index + 2] << 24) +
        (frame_buffer_data[array_index + 1] << 16) +
        (frame_buffer_data[array_index + 0] << 8) +
        frame_buffer_data[array_index + 3]
    ) >>> 0;

    eyedropper_p.innerText = `canvas width: ${ctx.canvas.width} height: ${ctx.canvas.height}
        mouse x: ${mouse_x} y: ${mouse_y}

        eyedropper x: ${eyedropper_x} y: ${eyedropper_y}
        pixel_index: ${pixel_index}
        array_index: ${array_index}
        pixel data: ${frame_buffer_data[array_index + 2]}, ${frame_buffer_data[array_index + 1]}, ${frame_buffer_data[array_index + 0]}, ${frame_buffer_data[array_index + 3]}
        hex: ${u32_pixel.toString(16).toUpperCase().padStart(8, "0")}
        u16: ${
            (frame_buffer_data[array_index + 2] << 8) +
            frame_buffer_data[array_index + 1]
        }, ${
            (frame_buffer_data[array_index + 0] << 8) +
            frame_buffer_data[array_index + 3]
        }
        u32: ${u32_pixel}
        0b${(u32_pixel.toString(2).padStart(32, "0").match(/.{1,8}/g) || []).join(' ')}
        gpu_time_spent: ${Math.round(gpu_time_spent.reduce((accumulate, current) => accumulate + current, 0) / gpu_time_spent.length)} μs
        use_interval: ${use_interval}
    `;
}

function update_eyedropper_pointer() {
    eyedropper_pointer.style.left = `${eyedropper_x + 5}px`;
    eyedropper_pointer.style.top = `${eyedropper_y + 5}px`;
}

export { ENTITY_COUNT_LOG2 }