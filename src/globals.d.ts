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
            width: number;
            height: number;
            seed: number;
            storageBuffer: worldBuffer | null;
            dimensionsUniform: GPUBuffer | null;
            NO_OF_SPRITES: number;
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
         * Initialized at {@link window.sprites} */
        spritesBuffer: { NO_OF_SPRITES: number, current: GPUBuffer | null, target: GPUBuffer | null };

        /** A uniform buffer that contains the dimensions of the viewport in `vec2f` */
        viewportUniform: GPUBuffer | null;

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
    }

    declare module "*.wgsl?raw" {
        const value: string;
        export default string;
    }
}

export {}