const { device, ctx } = await window.setUpGPU();

window.generateWorld.setUp(device);
window.world.storageBuffer = window.generateWorld.generateWorldStorageBuffer(window.world);
window.generateWorld.generateWorldToBuffer({...window.world, worldBuffer: window.world.storageBuffer});

window.renderWorld.setUp(device);
// window.renderWorld.writeViewportBuffer(canvas);
window.renderWorld.writeTransformUniform(window.camera);  
window.renderWorld.bindWorldStorageBuffer({...window.world, storageBuffer: window.world.storageBuffer});

window.canvasResize.setUp();
window.setUpRender({ device, ctx });

window.render(); // render and gametick are not synced