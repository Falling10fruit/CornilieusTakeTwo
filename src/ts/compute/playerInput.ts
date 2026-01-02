import { invoke } from '@tauri-apps/api/core'

async function bufferInput(device : GPUDevice) {
    const player_inputs = await invoke("get_player_inputs").catch((e) => { return e });
    if (!(player_inputs instanceof Array)) return window.fail({ title: "Couldn't get player inputs", message: player_inputs})

    if (window.world.playerInputBuffer == null) return window.fail({ title: "Player input buffer is null", message: "From src\ts\compute\playerInput.ts line 8"});
    device.queue.writeBuffer(window.world.playerInputBuffer, 0, new Uint32Array(player_inputs), 0, player_inputs.length);
}

export { bufferInput }