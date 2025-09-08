import * as canvasResize from "./prerequisites/canvasResize"
import { loadSpritesheet } from "./prerequisites/loadSpritesheet";
import { setUpGPU } from "./prerequisites/setUpGPU";

try {
    const { device, ctx } = await setUpGPU();

    canvasResize.setUp({ device });
    loadSpritesheet({ device });
    window.setUpRender({ device, ctx });

    window.generateWorld.setUp(device);
    window.world.storageBuffer = window.generateWorld.generateWorldStorageBuffer(window.world);
    window.generateWorld.generateWorldToBuffer({...window.world, worldBuffer: window.world.storageBuffer});

    window.renderWorld.setUp(device);
    window.renderWorld.bindWorldStorageBuffer({...window.world, worldBuffer: window.world.storageBuffer});


    window.render(); // render and gametick are not synced
} catch (err) {
    let message = "not parse-able";

    if (err instanceof Error) message = err.stack as string;
    if (typeof err == "string") message = err;

    if (message == "not parse-able") { console.error("failed to set up: ", message) } else
        window.fail({ title: "failed to set up", message});
}