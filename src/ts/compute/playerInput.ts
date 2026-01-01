import { invoke } from '@tauri-apps/api/core'

async function bufferInput(device : GPUDevice) {
    const player_inputs = await invoke("get_player_inputs").catch((e) => { return e })

    console.log(player_inputs);

    if (window.world.playerInputBufferMapped == null) return window.fail({ title: "Mapped player input buffer is null", message: "From src\ts\compute\playerInput.ts line 8"});
    window.world.playerInputBufferMapped.mapAsync(GPUMapMode.WRITE, 0, window.world.NO_OF_PLAYERS * 4);
    de
}

export { bufferInput }