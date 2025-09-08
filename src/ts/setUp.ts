import * as canvasResize from "./prerequisites/canvasResize"
import { loadSpritesheet } from "./prerequisites/loadSpritesheet";
import { setUpGPU } from "./prerequisites/setUpGPU";
import { setUpGenerateWorld, generateWorldStorageBuffer, generateWorldToBuffer } from "./generateWorldShader.ts";
import { setUpRenderWorld, bindWorldStorageBuffer } from "./render/renderWorld.ts";
import { setUpRender, render} from "./render/render.ts";

try {
    const { device, ctx } = await setUpGPU();

    canvasResize.setUp({ device });
    loadSpritesheet({ device });
    setUpRender({ device, ctx });

    setUpGenerateWorld({ device });
    window.world.storageBuffer = generateWorldStorageBuffer(window.world);
    generateWorldToBuffer({...window.world, worldBuffer: window.world.storageBuffer});

    setUpRenderWorld({ device });
    bindWorldStorageBuffer({...window.world, worldBuffer: window.world.storageBuffer});


    render(); // render and gametick are not synced
} catch (err) {
        window.fail({ title: "failed to set up", message: err });
}