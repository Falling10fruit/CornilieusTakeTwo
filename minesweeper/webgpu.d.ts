/// <reference types="@webgpu/types" />
/// <reference types="wesl-plugin/suffixes" />

declare global {
    interface SubgroupBuffers {
        copied_buffer: GPUBuffer,
        pasted_buffer: GPUBuffer,
        bind_group: GPUBindGroup
    }
    
    interface Window {    
        grid_dimensions: { width:number; height:number; }

        compute: {
            timing: {
                query_set: GPUQuerySet;
                resolve_buffer: GPUBuffer;
                /** mapped buffers to be unmapped to recieve gpu time */
                mapped_timed_buffers:Array<GPUBuffer>;
            };

            debug: {
                /** Buffer to contain the debug information to be copied to the unmapped buffers */
                copied_buffer: GPUBuffer;
                bind_group_layout: GPUBindGroupLayout;
                bind_group: GPUBindGroup;

                /** Unmapped buffer to recieve info and get mapped once */
                buffer: GPUBuffer;
            };

            minesweeper: {
                tiles_buffer:GPUBuffer;
                mouse_pos_buffer:GPUBuffer;
                bind_group_layout:GPUBindGroupLayout;
                bind_group:GPUBindGroup;
            }
        }
        
        render: {
            /** canvas dimensions */
            viewport_buffer: GPUBuffer;
            /** Extracted screen pixels for eyedropper */
            frame_buffer: GPUBuffer;

            bind_group_layout: GPUBindGroupLayout;
            bind_group: GPUBindGroup;
        };
    }
}

export {};