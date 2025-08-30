const { device, ctx } = await window.setUpGPU();

window.generateWorld.setUp(device);
window.world.storageBuffer = window.generateWorld.generateWorldStorageBuffer(window.world);
window.generateWorld.generateWorldToBuffer({...window.world, bufferCopySrc: window.world.storageBuffer});

window.renderWorld.setUp(device);
window.renderWorld.bindWorldStorageBuffer({...window.world, storageBuffer: window.world.storageBuffer});

window.canvasResize.setUp();

const renderPassDescriptor = {
    label: `canvas render pass`,
    colorAttatchments: [{
        clearValue: [0.0, 0.0, 0.0, 0.0],
        loadOp: `clear`,
        storeOp: `store`,
        view: ctx.getCurrentTexture().createView(),
    }],
};
window.render({ device, renderPassDescriptor}); // render and gametick are not synced