import hilbert_worker from "../generate/hilbert?worker"

if (self != undefined) {
    const vec2u = (x_pos: number, y_pos: number) => { return { x: x_pos, y: y_pos }}

    const points = [
        vec2u(0, 0),
        vec2u(0, 1),
        vec2u(1, 1),
        vec2u(1, 0)
    ];

    self.onmessage = (message) =>  {
        const { width, height } = message.data;
        let hilbert_array: Array<number> = [];
        for (let i = 0; i < width * height; i++) {
            hilbert_array.push(hilbert(i, width));
        }
        let hilbert_u32_array = new Uint32Array(hilbert_array);
        postMessage(hilbert_u32_array.buffer, { transfer: [hilbert_u32_array.buffer] });
    }
}

// Hilbert Curve implementation
// Adapted from Daniel Shiffman / The Coding Train
// Original tutorial: https://youtu.be/dSK-MW-zuAc
// License: GNU Lesser General Public License (LGPL v2.1)
function hilbert(i: number, width: number) {
    const points = [
        { x: 0, y: 0 },
        { x: 0, y: 1 },
        { x: 1, y: 1 },
        { x: 1, y: 0 }
    ];

    let index = i & 3;
    let v = points[index];

    for (let j = 1; j < Math.log2(width); j++) {
        i = i >>> 2;
        index = i & 3;
        let len = 2**j;

        if (index == 0) {
            let temp = v.x;
            v.x = v.y;
            v.y = temp;
        } else if (index == 1) {
            v.y += len;
        } else if (index == 2) {
            v.x += len;
            v.y += len;
        } else if (index == 3) {
            let temp = len - 1 - v.x;
            v.x = len - 1 - v.y;
            v.y = temp;
            v.x += len;
        }
    }

    return v.x + v.y * width
}

async function generateHilbert(parameters: { device: GPUDevice }) {
    const device = parameters.device;

    try {
        const hilbert_data = await new Promise((res, rej) => {
            const worker = new hilbert_worker();

            worker.onmessage = (event) => {
                res(event.data);
                worker.terminate();
            };

            worker.onerror = (error) => {
                rej(error);
                worker.terminate();
            }

            worker.postMessage({
                width: window.world.width,
                height: window.world.height
            });
        }) as ArrayBuffer;

        if (window.world.chunk_hilbert_curve_buffer == null) throw Error("window.world.chunk_hilbert_curve_buffer is null")
        device.queue.writeBuffer(window.world.chunk_hilbert_curve_buffer, 0, new Uint32Array(hilbert_data));
    } catch (error) {
        return window.fail({ title: "failed to generate hilbert", message: error });
    } 
}

export { generateHilbert }