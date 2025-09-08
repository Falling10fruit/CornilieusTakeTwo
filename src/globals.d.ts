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
        world: {
            width: number;
            height: number;
            seed: number;
            storageBuffer: worldBuffer | null;
        };

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
        spritesheet: { texture: GPUTexture | null; sampler: GPUSampler | null; };

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
        renderWorld: {
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
    }
}

export {}