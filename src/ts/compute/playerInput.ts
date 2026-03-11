import { invoke } from '@tauri-apps/api/core'

async function bufferInput(device : GPUDevice) {
    const player_inputs = await invoke("get_player_inputs").catch((e) => { return e });
    if (!(player_inputs instanceof Array)) return window.fail({ title: "Couldn't get player inputs", message: player_inputs});

    if (window.world.playerInputBuffer == null) return window.fail({ title: "Player input buffer is null", message: "From src\ts\compute\playerInput.ts"});
    device.queue.writeBuffer(window.world.playerInputBuffer, 0, new Uint32Array(player_inputs));
    
    // const commandEncoder = device.createCommandEncoder({ label: `compute entities command encoder` });
    
    // if (window.world.playerInputBufferMapped == null) return window.fail({ title: `player input buffer mapped is null`, message: `message generated in playerInputs.ts`});
    // const readBuffer = device.createBuffer({ label: `generateWorld readBuffer`, size: window.world.NO_OF_PLAYERS * 8 + 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST});
    // commandEncoder.copyBufferToBuffer(window.world.playerInputBuffer, window.world.playerInputBufferMapped);
    
    // device.queue.submit([commandEncoder.finish()]);

    // readBuffer.mapAsync(GPUMapMode.READ).then(() => {
    //     console.log(new Uint32Array(readBuffer.getMappedRange()));
    //     readBuffer.unmap();
    // });

    // requestAnimationFrame(simulateEntities);
}

export { bufferInput }