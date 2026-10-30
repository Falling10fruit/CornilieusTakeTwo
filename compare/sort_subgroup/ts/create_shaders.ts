import { link, createShaderModule } from "wesl";
import wgsl_source from "../wesl/main.wesl?link"

async function test_shaders(device:GPUDevice) {
    const linked = await link({
        ...wgsl_source,
        constants: { ENTITY_COUNT_LOG2: window.ENTITY_COUNT_LOG2 }
    });
    const shader = createShaderModule(linked, device, { label: "sort shader module" });;

    const encoder = device.createCommandEncoder({ label: "test command encoder" });
    const pass = encoder.beginComputePass({ label: "test compute pass" });
    pass.setBindGroup(0, window.gpu_main.entity_bind_group);
    pass.setBindGroup(1, window.gpu_sort.bind_group);

    interface EntryDetails { fn_name:string; workgroups:Array<number>;}
    const entry_id:Array<EntryDetails> = [
        { fn_name: "local_accumulation" , workgroups: [256, 256, 1] },
        { fn_name: "global_accumulation", workgroups: [256, 16,  1] },
        { fn_name: "global_prefix"      , workgroups: [16,  1,   1] },
        { fn_name: "digit_prefix"       , workgroups: [1,   1,   1] },
        { fn_name: "rescatter"          , workgroups: [256, 256, 1] },
    ];

    await Promise.all(
        entry_id.map((entry_details) => generate_test_pipeline(device, shader, entry_details.fn_name))
    ).then((pipelines) => { pipelines.forEach((pipeline, index) => {
        pass.setBindGroup(3, window.gpu_main.subgroup_test.list[index].bind_group);
        pass.setPipeline(pipeline);
        pass.dispatchWorkgroups(entry_id[index].workgroups[0], entry_id[index].workgroups[1], entry_id[index].workgroups[2]);
    })})
    
    window.gpu_main.subgroup_test.list.forEach(subgroup_test => {
        encoder.copyBufferToBuffer(subgroup_test.copied_buffer, subgroup_test.pasted_buffer);
    });

    device.queue.submit([encoder.finish()]);

    let subgroup_sizes:Array<number> = [];

    await Promise.all(window.gpu_main.subgroup_test.list.map(({pasted_buffer}) => pasted_buffer.mapAsync(GPUMapMode.READ)));
    window.gpu_main.subgroup_test.list.forEach(({pasted_buffer}, index) => {
        const recorded_subgroup_size = (new Uint32Array(pasted_buffer.getMappedRange()))[0];
        console.log(`${entry_id[index].fn_name} uses a subgroup size of ${recorded_subgroup_size}`);
        
        subgroup_sizes.push(recorded_subgroup_size);
    });

    return subgroup_sizes
}

async function generate_test_pipeline(device:GPUDevice, shader:GPUShaderModule, entry_point:string) {
    return device.createComputePipelineAsync({
        label: `${entry_point} test pipeline`,
        layout: device.createPipelineLayout({
            label: `${entry_point} test pipeline layoute`,
            bindGroupLayouts: [
                window.gpu_main.entity_bind_group_layout,
                window.gpu_sort.bind_group_layout,
                window.gpu_main.debug.gpu_bind_group_layout,
                
                window.gpu_main.subgroup_test.bind_group_layout
            ]
        }),
        compute: {
            module: shader,
            entryPoint: entry_point,
            constants: {
                BYTE_SHIFT: 0,
                SUBGROUP_SIZE: 16,

                IS_CHECKING_SUBGROUP_SIZE: 1 // only number
            }
        }
    });
}
