import chunk_count_source from "../../../wgsl/sort/chunk_count.wgsl?raw"
import chunk_prefix_workgroup_source from "../../../wgsl/sort/chunk_prefix_workgroup.wgsl?raw"
import chunk_prefix_source from "../../../wgsl/sort/chunk_prefix.wgsl?raw"
import chunk_rescatter_source from "../../../wgsl/sort/chunk_rescatter.wgsl?raw"

let device: GPUDevice;
let entity_buffer_bind_group_layout: GPUBindGroupLayout;
let sort_data_bind_group_layout: GPUBindGroupLayout;

let count_pipelines: Array<GPUComputePipeline | null> = [null, null, null, null];
let prefix_pipeline: GPUComputePipeline;
let prefix_workgroup_pipeline: GPUComputePipeline;
let rescatter_pipelines: Array<GPUComputePipeline | null> = [null, null, null, null];

let entity_buffer_bind_group: Array<GPUBindGroup>;
let sort_data_bind_group: GPUBindGroup;

async function create_sorting_pipelines(given_device: GPUDevice) {
    device = given_device;
    
    entity_buffer_bind_group_layout = device.createBindGroupLayout({
        label: `sort entities buffer bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }}, // entity buffer
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}, // the other entity buffer
        ]
    });
    
    sort_data_bind_group_layout = device.createBindGroupLayout({
        label: `sort entities histogram prefix bind group layout`,
        entries: [
            { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}, // byte count
            { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }}, // workgroup histogram
        ]
    });

    [
        prefix_pipeline,
        prefix_workgroup_pipeline,

    ] = await Promise.all([
        device.createComputePipelineAsync({
            label: `compute entities sort chunk_prefix_source pipeline`,
            layout: device.createPipelineLayout({
                label: `compute entities sort chunk_prefix_source pipeline layout`,
                bindGroupLayouts: [
                    entity_buffer_bind_group_layout,
                    sort_data_bind_group_layout
                ]
            }),
            compute: {
                module: device.createShaderModule({
                    label: `sort entities chunk prefix shader`,
                    code: chunk_prefix_source
                }),
                entryPoint: `chunk_prefix`,
            }
        }),
        device.createComputePipelineAsync({
            label: `compute entities sort chunk_prefix_workgroup_source pipeline`,
            layout: device.createPipelineLayout({
                label: `compute entities sort chunk_prefix_workgroup_source pipeline layout`,
                bindGroupLayouts: [
                    entity_buffer_bind_group_layout,
                    sort_data_bind_group_layout
                ]
            }),
            compute: {
                module: device.createShaderModule({
                    label: `sort entities chunk prefix workgroup shader`,
                    code: chunk_prefix_workgroup_source
                }),
                entryPoint: `chunk_prefix_workgroup`,
                constants: {
                    "ENTITY_COUNT_LOG2": window.world.ENTITIES_COUNT_LOG2
                }
            }
        }),
        create_sort_pass_pipelines(0),
        create_sort_pass_pipelines(1),
        create_sort_pass_pipelines(2),
        create_sort_pass_pipelines(3),
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

    if (window.world.entities.sort.byte_count_buffer == null) return window.fail({ title: "Buffer unavailable during entities base_entity_pipeline creation", message: "GPUBuffer window.world.entities.entities_buffer_0 is null" });
    if (window.world.entities.sort.workgroup_histogram_buffer == null) return window.fail({ title: "Buffer unavailable during entities pipeline creation", message: "GPUBuffer window.world.entities.entities_buffer_1 is null" });

    sort_data_bind_group = device.createBindGroup({
        label: `sort data bind group`,
        layout: sort_data_bind_group_layout,
        entries: [
            { binding: 0, resource: { buffer: window.world.entities.sort.byte_count_buffer } },
            { binding: 0, resource: { buffer: window.world.entities.sort.workgroup_histogram_buffer } },
        ]
    });
}

async function create_sort_pass_pipelines(iteration: number) {

    count_pipelines[iteration] = await device.createComputePipelineAsync({
        label: `compute entities sort chunk_count pipeline`,
        layout: device.createPipelineLayout({
            label: `compute entities sort chunk_count pipeline layout`,
            bindGroupLayouts: [
                entity_buffer_bind_group_layout,
                sort_data_bind_group_layout
            ]
        }),
        compute: {
            module: device.createShaderModule({
                label: `sort entities chunk count shader`,
                code: chunk_count_source
            }),
            entryPoint: `chunk_count`,
            constants: {
                "BIT_SHIFT": iteration * 4,
            }
        }
    });

    rescatter_pipelines[iteration] = await device.createComputePipelineAsync({
        label: `compute entities sort chunk_rescatter pipeline`,
        layout: device.createPipelineLayout({
            label: `compute entities sort chunk_rescatter pipeline layout`,
            bindGroupLayouts: [
                entity_buffer_bind_group_layout,
                sort_data_bind_group_layout
            ]
        }),
        compute: {
            module: device.createShaderModule({
                label: `sort entities chunk rescatter shader`,
                code: chunk_rescatter_source
            }),
            entryPoint: `chunk_rescatter`,
            constants: {
                "BIT_SHIFT": iteration * 4,
            }
        }
    });
}

function sort_entities(pass: GPUComputePassEncoder) {
    for (let i = 0; i < 4; i++) {
        pass.setBindGroup(0, entity_buffer_bind_group[1 - ((i & 1) ^ window.world.entities.current_entity_buffer_is)]);
        pass.setBindGroup(1, sort_data_bind_group);

        const count_pipeline = count_pipelines[i];
        if (count_pipeline == null) return window.fail({ title: "sort entities count pipeline is null", message: "During the entities compute pass"});
        pass.setPipeline(count_pipeline);
        pass.dispatchWorkgroups(8192 * window.world.ENTITIES_COUNT_LOG2 / 24);
        
        pass.setPipeline(prefix_pipeline);
        pass.dispatchWorkgroups(1)

        pass.setPipeline(prefix_workgroup_pipeline);
        pass.dispatchWorkgroups(16);

        const rescatter_pipeline = rescatter_pipelines[i];
        if (rescatter_pipeline == null) return window.fail({ title: "sort entities rescatter pipeline is null", message: "During the entities compute pass"});
        pass.setPipeline(rescatter_pipeline);
        pass.dispatchWorkgroups(8192 * window.world.ENTITIES_COUNT_LOG2 / 24);
    }
}

export { create_sorting_pipelines, sort_entities }