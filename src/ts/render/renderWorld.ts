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
            // struct TileTypesStruct { GREEN_STONE : TileFormat, DARK_STONE : TileFormat, AQUARITE : TileFormat, ICE : TileFormat }
            const tile_types_indexed: array<TileFormat, 4> = array(
                TileFormat(0u, 6u, vec2f(0.0,  0.0), vec2f(16.0, 16.0)),
                TileFormat(1u, 8u, vec2f(0.0, 16.0), vec2f(16.0, 32.0)),
                TileFormat(2u, 4u, vec2f(0.0, 32.0), vec2f(16.0, 48.0)),
                TileFormat(3u, 2u, vec2f(0.0, 48.0), vec2f(16.0, 64.0)) 
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
            @group(0) @binding(5) var<uniform> worldSize : vec2u;
            var<private> fWorldSize : vec2f;

            fn mixClamped (start : f32, end : f32, weight : f32) -> f32 { return min(end, max(start, mix(start, end, weight))); }
            
            fn interpolateAcrossTile(tileType : TileFormat, positionInTile : vec2f) -> vec2f {
                return vec2f(
                    mixClamped(tileType.atlasStart.x, tileType.atlasEnd.x, positionInTile.x),
                    mixClamped(tileType.atlasStart.y, tileType.atlasEnd.y, positionInTile.y)
                ) / vec2f(textureDimensions(spritesheet));
            }

            struct TileDataStruct {
                tile_type: TileFormat,
                hit_points: u32,
            }

            fn parse_raw_data (raw_data: u32) -> TileDataStruct {
                return TileDataStruct(
                    tile_types_indexed[(raw_data >> 30) & 3u],
                    (raw_data >> 25) & 31u
                );
            }

            fn get_tile_at (position: vec2f) -> TileDataStruct {
                let index : u32 = u32(floor(position.x) + floor(position.y) * fWorldSize.x);
                return parse_raw_data(sWorldData[index]);
            }

            @fragment fn fragmentShader( @builtin(position) v_position : vec4f ) -> @location(0) vec4f {
                fWorldSize = vec2f(worldSize * 8);

                var position : vec2f = (v_position.xy - uViewport/2.0) * vec2f(1.0, -1.0);
                position = vec2f(
                    position.x * cos(uTransform.rotation) - position.y * sin(uTransform.rotation),
                    position.x * sin(uTransform.rotation) + position.y * cos(uTransform.rotation)
                );
                position /= uTransform.scale;
                position += uTransform.translate;

                if (position.x < 0.0 || position.x > fWorldSize.x || position.y < 0.0 || position.y > fWorldSize.y) {
                    discard;
                }

                let tile_index: u32 = u32(floor(position.x) + floor(position.y) * fWorldSize.x);
                let tile_data : TileDataStruct = parse_raw_data(sWorldData[tile_index]);

                //     out_color = vec4(0.2, 0.5, 0.4, 1.0); // green stone
                //     out_color = vec4(0.2, 0.2, 0.2, 1.0); // dark stone
                //     out_color = vec4(0.6, 0.5, 0.2, 1.0); // aquarite
                //     out_color = vec4(1.0, 1.0, 1.0, 1.0); // ice

                var out_color : vec4f = vec4f(0.0, 0.0, 0.0, 0.0);

                out_color = textureSample(spritesheet, spritesheetSampler, interpolateAcrossTile(tile_data.tile_type, fract(position)));

                if (tile_data.hit_points == 0u) {
                    var occlusion: f32 = 0.0;

                    if (position.y < fWorldSize.y - 1.0) { if (parse_raw_data(sWorldData[tile_index + u32(fWorldSize.x)]).hit_points > 0u) {
                        occlusion = max(occlusion, fract(position.y) - 0.5);
                    }}
                        
                    if (position.y < fWorldSize.y - 1.0 && position.x < fWorldSize.x - 1.0) { if (parse_raw_data(sWorldData[tile_index + u32(fWorldSize.x) + 1]).hit_points > 0u) {
                        occlusion = max(occlusion, min(fract(position.y) - 0.5, fract(position.x) - 0.5));
                    }}
                        
                    if (position.x < fWorldSize.x - 1.0) { if (parse_raw_data(sWorldData[tile_index + 1]).hit_points > 0u) {
                        occlusion = max(occlusion, fract(position.x) - 0.5);
                    }}
                          
                    if (position.x < fWorldSize.x - 1.0 && position.y > 1.0) { if (parse_raw_data(sWorldData[tile_index + 1 - u32(fWorldSize.x)]).hit_points > 0u) {
                        occlusion = max(occlusion, min(fract(position.x) - 0.5, 0.5 - fract(position.y)));
                    }}

                    if (position.y > 1.0) { if (parse_raw_data(sWorldData[tile_index - u32(fWorldSize.x)]).hit_points > 0u) {
                        occlusion = max(occlusion, 0.5 - fract(position.y));
                    }}
                        
                    if (position.y > 1.0 && position.x > 1.0) { if (parse_raw_data(sWorldData[tile_index - u32(fWorldSize.x) - 1]).hit_points > 0u) {
                        occlusion = max(occlusion, min(0.5 - fract(position.y), 0.5 - fract(position.x)));
                    }}

                    if (position.x > 1.0) { if (parse_raw_data(sWorldData[tile_index - 1]).hit_points > 0u) {
                        occlusion = max(occlusion, 0.5 - fract(position.x));
                    }}
                        
                    if (position.x > 1.0 && position.y < fWorldSize.y - 1.0) { if (parse_raw_data(sWorldData[tile_index - 1 + u32(fWorldSize.x)]).hit_points > 0u) {
                        occlusion = max(occlusion, min(0.5 - fract(position.x), fract(position.y) - 0.5));
                    }}

                    out_color.x /= 1.5 + occlusion * 2;
                    out_color.y /= 1.5 + occlusion * 2;
                    out_color.z /= 1.5 + occlusion * 2;

                    // out_color = vec4f(occlusion, occlusion, occlusion, 1.0);
                }

                // out_color = vec4f(f32(tileData * 5)/255.0, 0.0, 0.0, 1.0);
                // out_color = vec4f(fract(position.y), 0.0, 0.0, 1.0); // apparently 1 px in position is one block
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
            { binding: 4, resource: { buffer: window.world.storageBuffer } } as GPUBindGroupEntry, // Tiles
            { binding: 5, resource: { buffer: window.world.dimensionsUniform } } as GPUBindGroupEntry // world size 
        ]
    });
    
    pipeline = await device.createRenderPipelineAsync({
        label: `render world pipeline`,
        layout: device.createPipelineLayout({
            label: `render world pipeline layout`,
            bindGroupLayouts: [bindGroupLayout],
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