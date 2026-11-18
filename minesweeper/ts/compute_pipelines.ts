import { createShaderModule, link } from "wesl";
import wesl from "./../webgpu/main.wesl?link"
const linked_wesl = await link({...wesl})

async function encode_pipelines_to_pass(pipelines:Record<string, GPUComputePipeline>, pass:GPUComputePassEncoder) {
    if (window.mouse.down) {
        pass.setBindGroup(0, window.compute.minesweeper.bind_group);
        pass.setBindGroup(1, window.compute.debug.bind_group);

        if (window.minesweeper.generated) {
            pass.setPipeline(pipelines["plant_bombs"]);
            pass.dispatchWorkgroups(Math.ceil(window.grid.no_of_tiles/256));
            pass.setPipeline(pipelines["mark_squares"]);
            pass.dispatchWorkgroups(Math.ceil(window.grid.no_of_tiles/256));
        }

        pass.setPipeline
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
    let square_len = Math.min(viewport_div_tiles.x, viewport_div_tiles.y);
    let grid_size = {
        x: square_len * window.grid.width,
        y: square_len * window.grid.height
    };
    let grid_top_left = {
        x: window.innerWidth/2 - grid_size.x/2,
        y: window.innerHeight/2 - grid_size.y/2,
    };

    device.queue.writeBuffer(window.compute.minesweeper.grid_dimensions_buffer, 0, new Uint32Array([
        window.grid.width, window.grid.height,
        square_len, 0,
        grid_size.x, grid_size.y,
        grid_top_left.x, grid_top_left.y
    ]));
}

export { return_compute_pipelines, encode_pipelines_to_pass, update_minesweeper_grid }