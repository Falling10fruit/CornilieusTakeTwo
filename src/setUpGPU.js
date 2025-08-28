async function setUpGPU() {
    if (!navigator.gpu) { window.fail({
        title: "WebGPU is not supported in this browser",
        message: "you should never see this error"
    }) }

    const adapter = await navigator.gpu?.requestAdapter();
    if (!adapter) { window.fail({
        title: "Unable to request adapter",
        message: "your device does not support WebGPU"
    }) }

    const device = await adapter.requestDevice();
    device.lost.then((e) => {
        window.fail({
            title: "WebGPU device lost",
            message: e.message
        });

        if (e.reason !== "destroyed") setUpGPU();
    });

    const ctx = document.getElementById("canvas").getContext("webgpu");
    ctx.configure({
        device: device,
        format: navigator.gpu.getPreferredCanvasFormat()
    });
    
    window.device = device;

    window.generateWorld.setUp();
    // window.renderWorld.setUp();

    // window.render(); // render and gametick are not synced
}

setUpGPU();

const errorBox = document.getElementById("error_box");
const header = errorBox.children[0];
const message = errorBox.children[1];
const close = errorBox.children[2];
const copy = errorBox.children[3];

window.fail = ({
    title = "huh.",
    message = "idk, shit happens ig"
}) => {
    header.innerText = title;
    message.innerText = message;
    
    close.onclick = closeBox;
    copy.onclick = copyText(message);
    
    errorBox.style.visibility = "visible";
    console.error(message);
}

function closeBox () {
    errorBox.style.visibility = "hidden";
}

async function copyText (message) {
    try {
        await navigator.clipboard.writeText(message);
    } catch (err) {
        alert("ERROR unable to copy error msg lol: ", err);
        console.error(err);
    }
}