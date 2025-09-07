/// <reference types="@webgpu/types" />
declare global {
    /** 
     * A storage buffer of type array\<u32\> containing information on the tiles in the world
     * ```
     * Tile type (2 bits) Hitpoints (5 bits)
     *        01                01010           1 01010101 01010101 01010101
     * ```*/
    type worldBuffer = GPUBuffer;
    
    interface Window {
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
         * Initialized at [preload.ts](preload.ts) */
        world: {
            width: number;
            height: number;
            seed: number;
            storageBuffer: worldBuffer | null;
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
         * Initialized at [preload.ts](preload.ts)
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
            uniformBuffer: GPUBuffer | null;
        };

        /** Each corresponding property, in the same format as `KeyboardEvent.key`, corresponds with a boolean as to whether or not the key is currently pressed */
        keyIsDown: Record<string, boolean>;

        /** Contains the spritesheet texture and its sampler. */
        spritesheet: {
            texture: GPUTexture | null;
            sampler: GPUSampler | null;
        };

        /** A uniform buffer that contains the dimensions of the viewport in `vec2f` */
        viewportUniform: GPUBuffer;

        /** Shows the error box with the given message and heading */
        fail: (parameters: { title: string, message: string}) => void;

        /** Create the WebGPU device and context.
         * 
         * Implementation at [setUpGPU.js](ts/prerequisites/setUpGPU.js)*/
        setUpGPU: () => { device: GPUDevice, ctx: GPUCanvasContext};

        /** Fetches the spritesheet, then creates a texture and sampler to {@link window.spritesheet}*/
        loadSpritesheet : (parameters: { device: GPUDevice}) => void;

        /** Sets up the {@link window.render} function */
        setUpRender: (parameters: { device: GPUDevice, ctx: GPUCanvasContext}) => void;
        
        /** An API to handle the world storage buffer.
         * 
         * Implementation at [generateWorldShader.js](ts/generateWorldShader)*/
        generateWorld: {
            /** Initializes the {@link window.generateWorld} methods.
             * 
             * Implementation at [generateWorldShader.js](ts/generateWorldShader) */
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

        /** An API to draw the world.
         * 
         * Implementation at [renderWorld.js](ts/render/renderWorld.js) */
        renderWorld: {
            /** Initializes methods for `window.renderWorld`
             * 
             * Implementation at [renderWorld.js](ts/render/renderWorld.js) */
            setUp: (device: GPUDevice) => void;
            
            /** Creates the API's bind group and binds the given storage buffer (worldBuffer).
             * 
             * Implementation at [renderWorld.js](ts/render/renderWorld.js)
             * @see {@link worldBuffer} */
            bindWorldStorageBuffer: (parameters: { width: number, height: number, worldBuffer: worldBuffer }) => void;

            /** Renders the world when called by `window.render()`
             * 
             * Implementation at [renderWorld.js](ts/render/renderWorld.js) */
            renderWorld: () => void;
        };

        /** The function that renders the entire frame.
         * 
         * Implementation at [render.js](ts/render/render.js) */
        render: () => void;
    }
}

export {}