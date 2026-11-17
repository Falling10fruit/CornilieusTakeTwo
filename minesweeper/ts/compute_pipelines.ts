import wgsl from "../webgpu/main.wgsl?raw"
import { create_minesweeper_objects } from "./initialize";

interface EntryDetails { fn_name:string; workgroups:Array<number>;}
let ENTRY_DETAILS:Array<EntryDetails> = [
    { fn_name: "plant_bombs" , workgroups: [256, 1, 1] }
];

async function encode_pipelines_to_pass(pipelines:Array<GPUComputePipeline>, pass:GPUComputePassEncoder) {
    pass.setBindGroup(0, window.compute.minesweeper.bind_group);
    pass.setBindGroup(2, window.compute.debug.bind_group); // For some reason the console is saying that there is a bindg group at index 3

    pipelines.forEach((pipeline, index) => {
        pass.setPipeline(pipeline);
        pass.dispatchWorkgroups(ENTRY_DETAILS[index].workgroups[0], ENTRY_DETAILS[index].workgroups[1], ENTRY_DETAILS[index].workgroups[2]);
    });
}

async function return_pipelines(device:GPUDevice) {
    const shader = device.createShaderModule({ label: "minesweeper shader module", code: wgsl });;
    return await Promise.all(ENTRY_DETAILS.map(({ fn_name }, index) => device.createComputePipelineAsync({
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
                
            }
        }
    })));
}

function update_minesweeper_grid(device:GPUDevice, parameters:{width:number, height:number}) {
    window.grid_dimensions = parameters;
    window.compute.minesweeper = create_minesweeper_objects(device);
}

export { ENTRY_DETAILS, return_pipelines, encode_pipelines_to_pass, update_minesweeper_grid }