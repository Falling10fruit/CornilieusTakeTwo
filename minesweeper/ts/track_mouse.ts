export default function add_listeners(device:GPUDevice) {
    window.onmousedown = () => { window.mouse.down = true; };
    window.onmouseup = () => { window.mouse.down = false; };
    window.onmousemove = (e) => {
        window.mouse.pos.x = e.clientX;
        window.mouse.pos.y = e.clientY;

        device.queue.writeBuffer(window.compute.minesweeper.mouse_pos_buffer, 0, new Uint32Array([
            window.mouse.pos.x,
            window.mouse.pos.y
        ]));
    }
}