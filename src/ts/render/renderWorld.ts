let device: GPUDevice;
let pipeline: GPURenderPipeline;
let worldSizeUniform: GPUBuffer;
let bindGroup: GPUBindGroup;

/** Initializes methods for the [renderWorld.ts](renderWorld.ts) module
 * 
 * Implementation at {@link setUpRenderWorld}*/
async function setUpRenderWorld (parameters: { device: GPUDevice }) {
    device = parameters.device;

    const vShader = device.createShaderModule({
        label: `render world vertex shader`,
        code: `
            const vertexArray : array<vec2f, 3> = array(
                vec2f(3.0, -1.0),
                vec2f(-1.0, -1.0),
                vec2f(-1.0, 3.0),
            );

            @vertex fn vertexShader( @builtin(vertex_index) vertexIndex : u32 ) -> @builtin(position) vec4f {
                return vec4f(vertexArray[vertexIndex], 0.0, 1.0);
            }
        `
    });

    const fShader = device.createShaderModule({
        label: `render world fragment shader`,
        code: `
            struct TileFormat { id : u32, hitPoints : u32, atlasStart : vec2f, atlasEnd : vec2f }
            struct TileTypesStruct { GREEN_STONE : TileFormat, DARK_STONE : TileFormat, AQUARITE : TileFormat, ICE : TileFormat }
            const TileTypes : TileTypesStruct = TileTypesStruct(
                TileFormat(0u, 6u, vec2f(0.0,  0.0), vec2f(16.0, 16.0)), // GREEN_STONE
                TileFormat(1u, 8u, vec2f(0.0, 16.0), vec2f(16.0, 32.0)), // DARK_STONE
                TileFormat(2u, 4u, vec2f(0.0, 32.0), vec2f(16.0, 48.0)), // AQUARITE
                TileFormat(3u, 2u, vec2f(0.0, 48.0), vec2f(16.0, 64.0))  // ICE
            );

            struct TransformStruct {
                @location(0) translate : vec2f,
                @location(1) scale : f32,
                @location(2) rotation : f32,
            }

            @group(0) @binding(0) var<uniform> uTransform : TransformStruct;
            @group(0) @binding(1) var<uniform> uViewport : vec2f;

            @group(0) @binding(2) var spritesheet : texture_2d<f32>;
            @group(0) @binding(3) var spritesheetSampler : sampler;

            @group(0) @binding(4) var<storage, read> sWorldData : array<u32>;
            @group(0) @binding(5) var<uniform> sWorldSize : vec2f;

            fn mixClamped (start : f32, end : f32, weight : f32) -> f32 { return min(end, max(start, mix(start, end, weight))); }
            
            fn interpolateAcrossTile(tileType : TileFormat, positionInTile : vec2f) -> vec2f {
                return vec2f(
                    mixClamped(tileType.atlasStart.x, tileType.atlasEnd.x, positionInTile.x),
                    mixClamped(tileType.atlasStart.y, tileType.atlasEnd.y, positionInTile.y)
                ) / vec2f(textureDimensions(spritesheet));
            }

            @fragment fn fragmentShader( @builtin(position) v_position : vec4f ) -> @location(0) vec4f {
                var position : vec2f = (v_position.xy - uViewport/2.0) * vec2f(1.0, -1.0);
                position = vec2f(
                    position.x * cos(uTransform.rotation) - position.y * sin(uTransform.rotation),
                    position.x * sin(uTransform.rotation) + position.y * cos(uTransform.rotation)
                );
                position /= uTransform.scale;
                position += uTransform.translate;

                if (position.x < 0.0 || position.x > sWorldSize.x || position.y < 0.0 || position.y > sWorldSize.y) {
                    discard;
                }

                let dataIndex : u32 = u32(floor(position.x) + floor(position.y) * sWorldSize.x);
                let tileData : u32 = sWorldData[dataIndex];

                let tileType : u32 = (tileData >> 30) & 3u;
                let hitPoints : u32 = (tileData >> 25) & 31u;

                //     out_color = vec4(0.2, 0.5, 0.4, 1.0); // green stone
                //     out_color = vec4(0.2, 0.2, 0.2, 1.0); // dark stone
                //     out_color = vec4(0.6, 0.5, 0.2, 1.0); // aquarite
                //     out_color = vec4(1.0, 1.0, 1.0, 1.0); // ice

                var out_color : vec4f = vec4f(0.0, 0.0, 0.0, 0.0);

                // switch (tileType) {
                //     case (TileTypes.GREEN_STONE.id) { out_color = vec4f(0.2, 0.5, 0.4, 1.0); }
                //     case (TileTypes.DARK_STONE.id) { out_color = vec4f(0.2, 0.2, 0.2, 1.0); }
                //     case (TileTypes.AQUARITE.id) { out_color = vec4f(0.6, 0.5, 0.2, 1.0); }    
                //     case (TileTypes.ICE.id) { out_color = vec4f(1.0, 1.0, 1.0, 1.0); }
                //     default { out_color = vec4f(0.0, 0.0, 0.0, 0.0); }
                // }

                var typeData : TileFormat;
                switch (tileType) {
                    case (TileTypes.GREEN_STONE.id) { typeData = TileTypes.GREEN_STONE; }
                    case (TileTypes.DARK_STONE.id) { typeData = TileTypes.DARK_STONE; }
                    case (TileTypes.AQUARITE.id) { typeData = TileTypes.AQUARITE; }    
                    case (TileTypes.ICE.id) { typeData = TileTypes.ICE; }
                    default { typeData = TileTypes.GREEN_STONE; }
                }

                out_color = textureSample(spritesheet, spritesheetSampler, interpolateAcrossTile(typeData, fract(position)));

                if (hitPoints == 0u) {
                    out_color.x /= 2.0;
                    out_color.y /= 2.0;
                    out_color.z /= 2.0;
                }

                // out_color = vec4f(f32(dataIndex)/255.0, 0.0, 0.0, 1.0);

                return out_color;
            }
        `
    });

    const bindGroupLayout = device.createBindGroupLayout({
        label: `render world group layout`,
        entries: [    
            { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry, // camera transform
            { binding: 1, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry, // viewport resolutoion
            { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: {} } as GPUBindGroupLayoutEntry,
            { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "non-filtering" }, } as GPUBindGroupLayoutEntry,
            { binding: 4, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" } } as GPUBindGroupLayoutEntry, // Tiles
            { binding: 5, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } } as GPUBindGroupLayoutEntry // world size
        ]
    });

    bindGroup = device.createBindGroup({
        label: `render world bind group`,
        layout: bindGroupLayout,
        entries: [
            { binding: 0, resource: { buffer: window.camera.uniformBuffer} } as GPUBindGroupEntry, // camera transform
            { binding: 1, resource: { buffer: window.viewportUniform } } as GPUBindGroupEntry, // viewport resolutoion
            { binding: 2, resource: window.spritesheet.texture } as GPUBindGroupEntry,
            { binding: 3, resource: window.spritesheet.sampler } as GPUBindGroupEntry,
            { binding: 0, resource: { buffer: window.world.storageBuffer } } as GPUBindGroupEntry, // Tiles
            { binding: 1, resource: { buffer: window.world.dimensionsUniform } } as GPUBindGroupEntry // world size 
        ]
    });
    
    pipeline = await device.createRenderPipelineAsync({
        label: `render world pipeline`,
        layout: device.createPipelineLayout({
            label: `render world pipeline layout`,
            bindGroupLayouts: [
                window.bindGroupLayouts.render[0], // camera
                window.bindGroupLayouts.render[1], // spritesheet
                window.bindGroupLayouts.render[2], // world data
            ],
        }),
        vertex: {
            module: vShader,
            entryPoint: "vertexShader",
        },
        fragment: {
            module: fShader,
            entryPoint: "fragmentShader",
            targets: [{
                format: navigator.gpu.getPreferredCanvasFormat(),
            }],
        },
    });

    worldSizeUniform = device.createBuffer({
        label: `render world world size uniform`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });
}

function renderWorld (pass: GPURenderPassEncoder) {
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(3);
};

export { setUpRenderWorld, renderWorld }