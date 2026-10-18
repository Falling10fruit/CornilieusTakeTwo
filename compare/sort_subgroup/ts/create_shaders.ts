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

    const workgroups = [
        [256, 256, 1],
        [256, 16, 1],
        [16, 1, 1],
    ];
    await Promise.all([
        generate_test_pipeline(device, shader, "local_accumulation"),
        generate_test_pipeline(device, shader, "global_accumulation"),
        generate_test_pipeline(device, shader, "global_prefix"),
    ]).then((pipelines) => { pipelines.forEach((pipeline, index) => {
        pass.setBindGroup(3, window.gpu_main.subgroup_test.list[index].bind_group);
        pass.setPipeline(pipeline);
        pass.dispatchWorkgroups(workgroups[index][0], workgroups[index][1], workgroups[index][2]);
    })})

    const subgroup_test_output_buffer = device.createBuffer({
        label: "subgroup test output buffer",
        size: window.gpu_main.subgroup_test.list.length,
        usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
    });
    window.gpu_main.subgroup_test.list.forEach(({ buffer }, index) => {
        encoder.copyBufferToBuffer(buffer, 0, subgroup_test_output_buffer, index, 1);
    });

    device.queue.submit([encoder.finish()]);
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
