import sort_wgsl from "../../../wgsl/sort_entities.wgsl?raw"

let device: GPUDevice;
let entity_buffer_bind_group_layout: GPUBindGroupLayout;
let digit_prefix_bind_group_layout: GPUBindGroupLayout;

let acummulate_pipelines: Array<GPUComputePipeline | null> = [null, null, null, null];
let prefix_sum_pipeline: GPUComputePipeline;
let rescatter_pipelines: Array<GPUComputePipeline | null> = [null, null, null, null];

let entity_buffer_bind_group: Array<GPUBindGroup>;
let digit_prefix_bind_group: GPUBindGroup;

async function create_sorting_pipelines(given_device: GPUDevice) {
    device = given_device;
    
    entity_buffer_bind_group_layout = device.createBindGroupLayout({
        label: `sort entities buffer bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}, // entity buffer
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}, // the other entity buffer
        ]
    });
    
    digit_prefix_bind_group_layout = device.createBindGroupLayout({
        label: `sort entities histogram prefix bind group layout`,
        entries: [{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } }] // digit prefix
    });

    const shader_module = device.createShaderModule({
        label: "sort entities shader module",
        code: sort_wgsl
    });

    [ prefix_sum_pipeline ] = await Promise.all([
        device.createComputePipelineAsync({
            label: `compute entities sort prefix sum pipeline`,
            layout: device.createPipelineLayout({
                label: `compute entities sort prefix sum pipeline layout`,
                bindGroupLayouts: [
                    entity_buffer_bind_group_layout,
                    digit_prefix_bind_group_layout
                ]
            }),
            compute: {
                module: shader_module,
                entryPoint: "prefix_sum",
                constants: { "ENTITY_COUNT_LOG2": window.world.ENTITIES_COUNT_LOG2 }
            }
        }),
        create_sort_pass_pipelines(0, shader_module),
        create_sort_pass_pipelines(1, shader_module),
        create_sort_pass_pipelines(2, shader_module),
        create_sort_pass_pipelines(3, shader_module),
    ]);

    if (window.world.entities.entities_buffer_0 == null) return window.fail({ title: "Buffer unavailable during entities base_entity_pipeline creation", message: "GPUBuffer window.world.entities.entities_buffer_0 is null" });
    if (window.world.entities.entities_buffer_1 == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.entities_buffer_1 is null" });

    entity_buffer_bind_group = [
        device.createBindGroup({
            label: `sort entities buffer 0 - 1 bind group`,
            layout: entity_buffer_bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: window.world.entities.entities_buffer_0 }},
                { binding: 1, resource: { buffer: window.world.entities.entities_buffer_1 }},
            ]
        }),
        
        device.createBindGroup({
            label: `sort entities buffer 1 - 0 bind group`,
            layout: entity_buffer_bind_group_layout,
            entries: [
                { binding: 0, resource: { buffer: window.world.entities.entities_buffer_1 }},
                { binding: 1, resource: { buffer: window.world.entities.entities_buffer_0 }},
            ]
        })
    ];

    if (window.world.entities.sort.digit_prefix_buffer == null) return window.fail({ title: "Buffer unavailable during entities sort set up", message: "GPUBuffer window.world.entities.sort.digit_prefix_buffer is null" });
    digit_prefix_bind_group = device.createBindGroup({
        label: `digit prefix bind group`,
        layout: digit_prefix_bind_group_layout,
        entries: [
            { binding: 0, resource: { buffer: window.world.entities.sort.digit_prefix_buffer } }
        ]
    });
}

async function create_sort_pass_pipelines(iteration: number, shader_module: GPUShaderModule) {

    acummulate_pipelines[iteration] = await device.createComputePipelineAsync({
        label: `compute entities sort chunk_count pipeline`,
        layout: device.createPipelineLayout({
            label: `compute entities sort chunk_count pipeline layout`,
            bindGroupLayouts: [
                entity_buffer_bind_group_layout,
                digit_prefix_bind_group_layout
            ]
        }),
        compute: {
            module: shader_module,
            entryPoint: `accumulate`,
            constants: {
                "BIT_SHIFT": iteration * 4,
                "ENTITY_COUNT_LOG2": window.world.ENTITIES_COUNT_LOG2,
            }
        }
    });

    rescatter_pipelines[iteration] = await device.createComputePipelineAsync({
        label: `compute entities sort chunk_rescatter pipeline`,
        layout: device.createPipelineLayout({
            label: `compute entities sort chunk_rescatter pipeline layout`,
            bindGroupLayouts: [
                entity_buffer_bind_group_layout,
                digit_prefix_bind_group_layout
            ]
        }),
        compute: {
            module: shader_module,
            entryPoint: `rescatter`,
            constants: {
                "BIT_SHIFT": iteration * 4,
                "ENTITY_COUNT_LOG2": window.world.ENTITIES_COUNT_LOG2,
            }
        }
    });
}

function sort_entities(pass: GPUComputePassEncoder) {
    for (let i = 0; i < 4; i++) {
        pass.setBindGroup(0, entity_buffer_bind_group[1 - ((i & 1) ^ window.world.entities.current_entity_buffer_is)]);
        pass.setBindGroup(1, digit_prefix_bind_group);

        const count_pipeline = acummulate_pipelines[i];
        if (count_pipeline == null) return window.fail({ title: "sort entities count pipeline is null", message: "During the entities compute pass"});
        pass.setPipeline(count_pipeline);
        pass.dispatchWorkgroups(8192 >> (24 - window.world.ENTITIES_COUNT_LOG2));

        pass.setPipeline(prefix_sum_pipeline);
        pass.dispatchWorkgroups(16);

        const rescatter_pipeline = rescatter_pipelines[i];
        if (rescatter_pipeline == null) return window.fail({ title: "sort entities rescatter pipeline is null", message: "During the entities compute pass"});
        pass.setPipeline(rescatter_pipeline);
        pass.dispatchWorkgroups(8192 >> (24 - window.world.ENTITIES_COUNT_LOG2));
    }
}

export { create_sorting_pipelines, sort_entities }