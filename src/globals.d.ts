/// <reference types="@webgpu/types" />
declare global {
    /** 
     * A storage buffer of type array\<u32\> containing information on the tiles in the world
     * ```
     * Tile type (2 bits) Hitpoints (5 bits)
     *        01                01010           1 01010101 01010101 01010101
     * ```*/
    type worldBuffer = GPUBuffer;

    /**
     * A uniform buffer that contains transformation data about the  
     * 
     * The uniform buffer is a struct:
     * ```
     *  struct TransformStruct {
     *      location(0) translate : vec2f,
     *      location(1) scale : f32,
     *      location(2) rotation : f32,
     *  }
     * ```
     * The `@` is implicit; they are reserved in JSDoc.
     */
    type cameraBuffer = GPUBuffer;
    
    /** WebGPU is sometimes incompatible */
    type trust_me = any;
    
    interface Window { 
        /** 
         * render:
         *      camera
         *      spritesheet
         *      worldData
         *      the sprite buffer ( read only )
         */
        bindGroupLayouts: {
            render: Array<GPUBindGroupLayout  | null>,
            compute: Array<GPUBindGroupLayout  | null>,
        }
        /** for the list @see bindGroupLayouts */
        bindGroups: {
            render: Array<GPUBindGroup  | null>,
            compute: Array<GPUBindGroup  | null>,
        };

        /**
         * Where the game world information is set.
         * 
         * @default
         * ```
         *  window.world = {
         *      width: 80,
         *      height: 60,
         *      seed: 43758.5453,
         *      storageBuffer: null, 
         * }
         * ```
         * Initialized at {@link window.world} */
        world: {
            seed: number;
            /** In terms of chunks (as of 2025, a chunk is 8 by 8) */
            width: number;
            /** In terms of chunks (as of 2025, a chunk is 8 by 8) */
            height: number;
            chunk_hilbert_curve_buffer: null | GPUBuffer;
            storageBuffer: worldBuffer | null;
            dimensionsUniform: GPUBuffer | null;
            NO_OF_SPRITES: number;
            ENTITIES_COUNT_LOG2: number;

            MAX_PLAYERS: number; // Maybe allow the host to change it mid stage AFTER I actually make the game
            player_count: number;
            playerCountUniform: GPUBuffer | null;
            playerInputBuffer: GPUBuffer | null;
            playerInputBufferMapped : GPUBuffer | null;

            entities: {
                /**
                 * A buffer of struct EntityDataStruct defined as:
                 * 
                 * 
                 * ```wgsl+
                 * struct EntityData {
                 *     node_count: u32,
                 *     node_pointer: u32,
                 *     center: vec2f,
                 *     dimensions: vec2f,
                 *     mass: f32,
                 *     default_sprite: u32
                    }
                    * ```
                    */
                type_data_buffer: GPUBufer | null,
                /**
                 * A buffer of vec2f indexed by the node pointers in the entity_data buffer
                 */
                node_data_buffer : GPUBuffer | null
                indirect_count_buffer: GPUBuffer | null,
                /** which sprites are which entities */
                entities_indicies: GPUBuffer | null,
                /** Holds the index of the chunk the entity is currently in
                 * has no_of_chunks + 1 elements, the last one has a value of length(entities_buffer)
                */
                chunk_indicies: GPUBuffer | null,
                /** Decides which entity texture is going to be used, results either 0 or 1 */
                current_entity_buffer_is: number,
                /** The first 3D texture that holds entity data, alternates with the second based on `current_entity_texture_is`
                 * 
                 * The x and y determine the position of the chunk and and z axis holds all the entities within that chunk */
                entities_buffer_0: GPUBuffer | null,
                /** The second 3D texture that holds entity data, alternates with the first based on `current_entity_texture_is`
                 * 
                 * The x and y determine the position of the chunk and and z axis holds all the entities within that chunk */
                entities_buffer_1: GPUBuffer | null,
                /**
                 * An additional buffer containing data for whatever operation is currently done
                 * i.e. indicies of colliding entities during narrow phase collision
                 */
                meta_buffer: GPUBuffeer | null,

                /**
                 * Consists of buffers used for sorting entities at the end
                 * ```wgsl
                 * @group(0) @binding(1) var<storage, read_write> digit_prefix : array<array<u32, 16>>;
                 * @group(0) @binding(2) var<storage, read_write> workgroup_histogram : array<array<u32, 16>>;
                 * ```
                 */
                sort: {
                    /**
                     * Counts how many are there of each digit and also has the prefix across the digits
                     * 
                     * Curiously prefix sum is never used. 17 me was weird, I'm still 17 tho.
                     * ```wgsl
                     * @group(0) @binding(1) var<storage, read_write> digit_prefix : array<array<u32, 16>>;
                     * ```
                     */
                    digit_prefix_buffer: GPUBuffer | null,
                    /**
                     * Keeps a histogram of how many numbers of 16 are in each of the 8192 chunks
                     * 
                     * ```wgsl
                     * @group(0) @binding(2) var<storage, read_write> workgroup_histogram : array<array<u32, 16>>;
                     * ```
                     */
                    workgroup_histogram_buffer: GPUBuffer | null
                }
            }
        };

        /**
         * Where the camera information is set.
         * 
         * @default
         * ```
         *  window.camera = {
         *      xPos: 0,
         *      yPos: 0,
         *      yVel: 0,
         *      xVel: 0,
         *      scale: 16,
         *      scaleVel: 0,
         *      rotation: (0)*Math.PI/180,
         *      rotationVel: 0,
         *      uniformBuffer: null,
         *  };
         * ```
         * Initialized at {@link window.camera}
         */
        camera: {
            xPos: number;
            yPos: number;
            yVel: number;
            xVel: number;
            scale: number;
            scaleVel: number;
            /** Value is interperted in radians */
            rotation: number;
            /** Value is interperted in radians */
            rotationVel: number;
            uniformBuffer: cameraBuffer | null;
        };

        /** Each corresponding property, in the same format as `KeyboardEvent.key`, corresponds with a boolean as to whether or not the key is currently pressed */
        keyIsDown: Record<string, boolean>;

        /** Contains the spritesheet texture and its sampler. */
        spritesheet: { texture: GPUTexture | null; sampler: GPUSampler | null; };

        /** Contains the sprites to be rendered
         * ```
         *    y       x     rotation   sprite
         * 1111111 1111111 111111111  111111111 
         *   128     128      512       512
         *                  591645
         * ```
         * Initialised at [createBuffers.js](ts/prerequisites/createBuffers.ts)*/
        spritesBuffer: { current: GPUBuffer | null, target: GPUBuffer | null };

        /** A uniform buffer that contains the dimensions of the viewport in `vec2f` */
        viewportUniform: GPUBuffer | null;

        /** 2d culling */
        depth_texture: GPUTexture | null;

        cosin_lut_buffer: GPUBuffer | null;

        /** Shows the error box with the given message and heading.
         * 
         * Implementation at {@link window.fail}*/
        fail: (parameters: { title: string, message: unknown }) => void;
        
        /** An API to handle the world storage buffer.
         * 
         * Implementation at [generateWorldShader.js](ts/generateWorldShader)*/
        generateWorld: {
            setUp: (device: GPUDevice) => void;

            /** 
             * @yields { worldBuffer } A storage buffer of the requested dimensions in chunks.
             * 
             * Implementation at [generateWorldShader.js](ts/generateWorldShader.js).
             * @see {@link worldBuffer} */
            generateWorldStorageBuffer: (parameters: { width: number, height: number }) => worldBuffer;
            
            /** Writes pseudo random world to the given storage buffer (worldBuffer).
             * 
             * Implementation at [generateWorldShader.js](ts/generateWorldShader.js).
             * @see {@link worldBuffer}*/
            generateWorldToBuffer: (parameters: { width: number, height: number, worldBuffer: worldBuffer}) => void;
        };

        debug: {
            buffer: GPUBuffer | null,
            unmapped_buffers: Array<GPUBuffer> | null,
        }
    }

    declare module "*.wgsl?raw" {
        const value: string;
        export default string;
    }
}

export {}