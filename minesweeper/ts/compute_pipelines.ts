import { link, createShaderModule } from "wesl";
import wesl_source from "../webgpu/main.wesl?link"

const ENTITY_COUNT_LOG2 = 21;  // only down to 20
const linked = await link({
    ...wesl_source,
    constants: { ENTITY_COUNT_LOG2 }
});

interface EntryDetails { fn_name:string; workgroups:Array<number>;}
const ENTRY_DETAILS:Array<EntryDetails> = [
    { fn_name: "local_accumulation" , workgroups: [256, 256, 1] }
];

async function encode_pipelines_to_pass(pipelines:Array<GPUComputePipeline>, pass:GPUComputePassEncoder) {
    pass.setBindGroup(0, window.compute.entity.bind_group);
    pass.setBindGroup(1, window.compute.sort.bind_group);
    pass.setBindGroup(2, window.compute.debug.bind_group); // For some reason the console is saying that there is a bindg group at index 3

    pipelines.forEach((pipeline, index) => {
        pass.setBindGroup(3, window.compute.subgroup_test.list[index].bind_group);
        pass.setPipeline(pipeline);
        pass.dispatchWorkgroups(ENTRY_DETAILS[index].workgroups[0], ENTRY_DETAILS[index].workgroups[1], ENTRY_DETAILS[index].workgroups[2]);
    });
}

async function return_pipelines(device:GPUDevice) {
    const shader = createShaderModule(linked, device, { label: "sort shader module" });;
    return await Promise.all(ENTRY_DETAILS.map(({ fn_name }, index) => device.createComputePipelineAsync({
        label: `${fn_name} pipeline`,
        layout: device.createPipelineLayout({
            label: `${fn_name} pipeline layouts`,
            bindGroupLayouts: [
                window.compute.entity.bind_group_layout,
                window.compute.sort.bind_group_layout,
                window.compute.debug.bind_group_layout,
                // DCE not working idk why
                window.compute.subgroup_test.bind_group_layout
            ]
        }),
        compute: {
            module: shader,
            entryPoint: fn_name
        }
    })));
}

export { ENTITY_COUNT_LOG2, ENTRY_DETAILS, return_pipelines, encode_pipelines_to_pass }