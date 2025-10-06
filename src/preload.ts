import { createBuffers } from "./ts/prerequisites/createBuffers";
import { loadSpritesheet } from "./ts/prerequisites/loadSpritesheet.ts";
import { createBindGroupsAndLayouts } from "./ts/prerequisites/setUpBindGroups";

async function preload (parameters: { device: GPUDevice }) {
    const eyedropper = document.createElement("input");
    eyedropper.type = "color";

    window.world = {
        width: 80,
        height: 60,
        seed: 43758.5453,
        storageBuffer: null,
        dimensionsUniform: null,
        NO_OF_SPRITES: 2**24
    };

    window.camera = {
        xPos: 0,
        yPos: 0,
        yVel: 0,
        xVel: 0,
        scale: 16,
        scaleVel: 0,
        rotation: (0)*Math.PI/180,
        rotationVel: 0,
        uniformBuffer: null,
    };

    window.spritesheet = {
        texture: null,
        sampler: null,
    };

    window.bindGroupLayouts = { render: [], compute: [] }
    window.bindGroups = { render: [], compute: [] }

    window.keyIsDown = {};

    window.onkeyup = (e) => { window.keyIsDown[e.key] = false; }
    window.onkeydown = (event) => {
        window.keyIsDown[event.key] = true;
        console.log(event.key);

        if (event.key === "F2") eyedropper.click();
    };

    createBuffers({ ...parameters });
    await loadSpritesheet({ ...parameters });
    createBindGroupsAndLayouts({ ...parameters });
}

export { preload }