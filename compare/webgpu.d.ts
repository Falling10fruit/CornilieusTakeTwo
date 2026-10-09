/// <reference types="@webgpu/types" />
// 
declare module '*?static' {
  const content: string;
  export default content;
}

declare global { interface Window { wesl: {
    timing: {
        query_set: GPUQuerySet;
        resolve_buffer: GPUBuffer;
    },

    render: {
        /** canvas dimensions */
        viewport_buffer: GPUBuffer;
        /** Extracted screen pixels for eyedropper */
        frame_buffer: GPUBuffer;
        /** mapped buffers to be unmapped to recieve screen pixels */
        mapped_timed_buffers:Array<GPUBuffer>;
    }

    debug: {
        /** Buffer to contain the debug information to be copied to the unmapped buffers */
        gpu_buffer: GPUBuffer;
        /** Unmapped buffer to recieve info and get mapped once */
        buffer: GPUBuffer;
    }

    entity_buffer_0: GPUBuffer;
    entity_buffer_1: GPUBuffer;
    workgroup_histogram: GPUBuffer;
    global_histogram: GPUBuffer;
} } }