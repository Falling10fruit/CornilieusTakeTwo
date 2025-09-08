import * as canvasResize from "./prerequisites/canvasResize"
import { loadSpritesheet } from "./prerequisites/loadSpritesheet";
import { setUpGPU } from "./prerequisites/setUpGPU";
import { setUpRender, render} from "./render/render.ts";
import { setUpRenderWorld, bindWorldStorageBuffer } from "./render/renderWorld.ts";

try {
    const { device, ctx } = await setUpGPU();

    canvasResize.setUp({ device });
    loadSpritesheet({ device });
    setUpRender({ device, ctx });

    window.generateWorld.setUp(device);
    window.world.storageBuffer = window.generateWorld.generateWorldStorageBuffer(window.world);
    window.generateWorld.generateWorldToBuffer({...window.world, worldBuffer: window.world.storageBuffer});

    setUpRenderWorld({ device });
    bindWorldStorageBuffer({...window.world, worldBuffer: window.world.storageBuffer});


    render(); // render and gametick are not synced
} catch (err) {
        window.fail({ title: "failed to set up", message: err });
}