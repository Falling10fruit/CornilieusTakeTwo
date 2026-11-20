export default function add_listeners(device:GPUDevice) {
    window.onmousedown = (e) => {
        window.mouse.down = true;
        window.mouse.button = e.button;
    };

    window.onmousemove = (e) => {
        window.mouse.pos.x = e.clientX;
        window.mouse.pos.y = e.clientY;
    }
}