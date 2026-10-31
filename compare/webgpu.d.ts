/// <reference types="@webgpu/types" />
/// <reference types="wesl-plugin/suffixes" />

declare global {
    interface SubgroupBuffers {
        copied_buffer: GPUBuffer,
        pasted_buffer: GPUBuffer,
        bind_group: GPUBindGroup
    }
    
    interface Window {    
        ENTITY_COUNT_LOG2:number,
        gpu: {
            timing: {
                query_set: GPUQuerySet;
                resolve_buffer: GPUBuffer;
                /** mapped buffers to be unmapped to recieve gpu time */
                mapped_timed_buffers:Array<GPUBuffer>;
            };

            render: {
                /** canvas dimensions */
                viewport_buffer: GPUBuffer;
                /** Extracted screen pixels for eyedropper */
                frame_buffer: GPUBuffer;

                bind_group_layout: GPUBindGroupLayout;
                bind_group: GPUBindGroup;
            };

            subgroup_test: {
                bind_group_layout:GPUBindGroupLayout;
                list: Array<SubgroupBuffers>;
            };

            debug: {
                /** Buffer to contain the debug information to be copied to the unmapped buffers */
                copied_buffer: GPUBuffer;
                bind_group_layout: GPUBindGroupLayout;
                bind_group: GPUBindGroup;

                /** Unmapped buffer to recieve info and get mapped once */
                buffer: GPUBuffer;
            };

            entity: {
                buffer_0: GPUBuffer;
                buffer_1: GPUBuffer;
                bind_group_layout: GPUBindGroupLayout;
                bind_group: GPUBindGroup;
            };

            sort: {
                workgroup_histogram: GPUBuffer;
                global_histogram: GPUBuffer;
                digit_histogram: GPUBuffer;
                bind_group_layout: GPUBindGroupLayout;
                bind_group: GPUBindGroup;
            }
        }
    }
}

export {};