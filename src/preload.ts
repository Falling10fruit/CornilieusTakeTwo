import { invoke, Channel } from "@tauri-apps/api/core";
import { createBuffers } from "./ts/prerequisites/createBuffers";
import { loadSpritesheet } from "./ts/prerequisites/loadSpritesheet.ts";

async function preload (parameters: { device: GPUDevice }) {
    const eyedropper = document.createElement("input");
    eyedropper.type = "color";

    window.world = {
        width: 80, // These
        height: 60,
        seed: 43758.5453,
        storageBuffer: null,
        dimensionsUniform: null,
        NO_OF_SPRITES: 2**15,
        NO_OF_ENTITIES: 2**16,

        MAX_PLAYERS: 1, // aka singleplayer
        player_count: 1,
        playerInputBuffer: null,
        playerInputBufferMapped: null
    };

    window.camera = {
        xPos: 3,
        yPos: 3,
        yVel: 0,
        xVel: 0,
        scale: 64,
        scaleVel: 0,
        rotation: (0)*Math.PI/180,
        rotationVel: 0,
        uniformBuffer: null,
    };

    window.spritesheet = {
        texture: null,
        sampler: null,
    };

    window.spritesBuffer = {
        current: null,
        target: null
    }
    
    window.entitiesBuffer = {
        entities_indicies: null,
        chunk_indicies: null,
        current_entity_buffer_is: 0,
        entities_buffer_0: null,
        entities_buffer_1: null,
    }

    window.keyIsDown = {};

    const key_channel = new Channel();
    // invoke(`key_stroke_stream`);

    window.onkeyup = (e) => { window.keyIsDown[e.key] = false; }
    window.onkeydown = (event) => {
        window.keyIsDown[event.key] = true;
        console.log(event.code);

        if (event.key === "F2") eyedropper.click();

    };

    window.debug = {
        buffer: null,
        mapped_buffer: null
    };

    createBuffers({ ...parameters });
    await loadSpritesheet({ ...parameters });
}

export { preload }