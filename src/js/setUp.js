const { device, ctx } = await window.setUpGPU();

window.canvasResize.setUp({ device });
window.loadSpritesheet({ device });
window.setUpRender({ device, ctx });

window.generateWorld.setUp(device);
window.world.storageBuffer = window.generateWorld.generateWorldStorageBuffer(window.world);
window.generateWorld.generateWorldToBuffer({...window.world, worldBuffer: window.world.storageBuffer});

window.renderWorld.setUp(device);
window.renderWorld.bindWorldStorageBuffer({...window.world, storageBuffer: window.world.storageBuffer});


window.render(); // render and gametick are not synced