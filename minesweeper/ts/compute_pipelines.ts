import { createShaderModule, link } from "wesl";
import wesl from "./../webgpu/main.wesl?link"
const linked_wesl = await link({...wesl})

const get_tile_idx_on_mouse = () => {
    let relative_mouse_pos = {
        x: window.mouse.pos.x - window.grid.top_left.x,
        y: window.mouse.pos.y - window.grid.top_left.y
    };
    let tile_pos = {
        x: Math.floor(relative_mouse_pos.x/window.grid.square_len),
        y: Math.floor(relative_mouse_pos.y/window.grid.square_len)
    };
    return tile_pos.x + tile_pos.y * window.grid.width;
};

async function encode_pipelines_to_pass(pass:GPUComputePassEncoder, pipelines:Record<string, GPUComputePipeline>, device:GPUDevice) {
    let inbound = handle_mouse(pass, pipelines, device);

    if (window.mouse.down) {
        pass.setBindGroup(0, window.compute.minesweeper.bind_group);
        pass.setBindGroup(1, window.compute.debug.bind_group);


        pass.setPipeline(pipelines["tick"])
    }
}

function handle_mouse(pass:GPUComputePassEncoder, pipelines:Record<string, GPUComputePipeline>, device:GPUDevice) {
    let mouse_inbound =
        window.mouse.pos.x > window.grid.top_left.x &&
        window.mouse.pos.y > window.grid.top_left.y &&
        window.mouse.pos.x < (window.grid.top_left.x + window.grid.size.x) &&
        window.mouse.pos.y < (window.grid.top_left.y + window.grid.size.y);
    if (!mouse_inbound) { return; }

    if (window.minesweeper.generated) {
        pass.setPipeline(pipelines["plant_bombs"]);
        pass.dispatchWorkgroups(Math.ceil(window.grid.no_of_tiles/256));
        pass.setPipeline(pipelines["mark_squares"]);
        pass.dispatchWorkgroups(Math.ceil(window.grid.no_of_tiles/256));
    } else {
        let mouse_idx = get_tile_idx_on_mouse();
        
    }
}

async function return_compute_pipelines(device:GPUDevice) {
    const shader = createShaderModule(linked_wesl, device, { label: 'compute shader module' });
    return {
        "plant_bombs": create_pipeline(device, shader, "plant_bombs"),
        "mark_squares": create_pipeline(device, shader, "mark_squares")
    } // Promise.all(ENTRY_DETAILS.map(({ fn_name }, index) => ));
}

async function create_pipeline(device:GPUDevice, shader:GPUShaderModule, fn_name:string) {
    return device.createComputePipelineAsync({
        label: `${fn_name} pipeline`,
        layout: device.createPipelineLayout({
            label: `${fn_name} pipeline layouts`,
            bindGroupLayouts: [
                window.compute.minesweeper.bind_group_layout,
                window.compute.debug.bind_group_layout
            ]
        }),
        compute: {
            module: shader,
            entryPoint: fn_name,
            constants: {
                "seed": Date.now() & 0xFFFFFFFF,
                "viewport_width": window.innerWidth,
                "viewport_height": window.innerHeight,
            }
        }
    })
}

function update_minesweeper_grid(device:GPUDevice) {
    let viewport_div_tiles = {
        x: (window.innerWidth - 2 * window.grid.viewport_padding)/window.grid.width,
        y: (window.innerHeight - 2 * window.grid.viewport_padding)/window.grid.height,
    };
    window.grid.square_len = Math.min(viewport_div_tiles.x, viewport_div_tiles.y);
    window.grid.size = {
        x: window.grid.square_len * window.grid.width,
        y: window.grid.square_len * window.grid.height
    };
    window.grid.top_left = {
        x: window.innerWidth/2 - window.grid.size.x/2,
        y: window.innerHeight/2 - window.grid.size.y/2,
    };

    device.queue.writeBuffer(window.compute.minesweeper.grid_dimensions_buffer, 0, new Uint32Array([
        window.grid.width, window.grid.height,
        window.grid.square_len, 0,
        window.grid.size.x, window.grid.size.y,
        window.grid.top_left.x, window.grid.top_left.y
    ]));
}

export { return_compute_pipelines, encode_pipelines_to_pass, update_minesweeper_grid }