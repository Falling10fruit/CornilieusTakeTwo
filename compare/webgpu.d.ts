/// <reference types="@webgpu/types" />
/// <reference types="wesl-plugin/suffixes" />

declare global {
    interface SubgroupBuffers {
        copied_buffer: GPUBuffer,
        pasted_buffer: GPUBuffer,
        bind_group: GPUBindGroup
    }
    
    interface MainStuff {
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
        };
        subgroup_test: {
            bind_group_layout:GPUBindGroupLayout;
            list: Array<SubgroupBuffers>;
        };
        debug: {
            /** Buffer to contain the debug information to be copied to the unmapped buffers */
            gpu_buffer: GPUBuffer;
            gpu_bind_group_layout: GPUBindGroupLayout;
            /** Unmapped buffer to recieve info and get mapped once */
            buffer: GPUBuffer;
        };

        entity_buffer_0: GPUBuffer;
        entity_buffer_1: GPUBuffer;
        entity_bind_group_layout: GPUBindGroupLayout;
        entity_bind_group: GPUBindGroup;
    }
    
    interface Window {    
        ENTITY_COUNT_LOG2:number,
        gpu_main:MainStuff
    }
}

export {};