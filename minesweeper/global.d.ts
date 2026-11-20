/// <reference types="@webgpu/types" />
/// <reference types="wesl-plugin/suffixes" />

declare global {
    interface SubgroupBuffers {
        copied_buffer: GPUBuffer,
        pasted_buffer: GPUBuffer,
        bind_group: GPUBindGroup
    }

    interface Window {
        minesweeper: {
            /** If the level is generated yet (generates during first click) */
            generated:boolean;
        }

        
        mouse: {
            down:boolean;
            /** 0: left | 1 right
             * Set upon mouse down
            */
            button:number;
            pos:{x:number,y:number}
        }
        
        grid: {
            viewport_padding: 50;

            max_width:number;
            max_height: number;

            width:number;
            height:number;
            square_len:number;
            size:{x:number, y:number};
            top_left:{x:number, y:number};


            no_of_tiles:number;
        }

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
                /**
                 * ```wgsl
                 * struct Grid {
                 *     dimensions:vec2u,
                 *     square_len:u32,
                 *     grid_size:vec2u,
                 *     grid_top_left:vec2u
                 * }
                 * ```
                 */
                grid_dimensions_buffer:GPUBuffer;
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

    
    declare module '*.wgsl?raw' {
        const value: string;
        export default value;
    }
}

export {};