const global = window.renderWorld = {};
global.setUp = (device) => {
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
            struct TileFormat { id : u32, hitPoints : u32 }
            struct TileTypesStruct { GREEN_STONE : TileFormat, DARK_STONE : TileFormat, AQUARITE : TileFormat, ICE : TileFormat }
            const TileTypes : TileTypesStruct = TileTypesStruct(
                TileFormat(0u, 6u), // GREEN_STONE
                TileFormat(1u, 8u), // DARK_STONE
                TileFormat(2u, 4u), // AQUARITE
                TileFormat(3u, 2u)  // ICE
            );

            @group(0) @binding(0) var<storage, read> sWorldData : array<u32>;
            @group(0) @binding(1) var<uniform> sWorldSize : vec2f;

            struct TransformStruct {
                @location(0) position : vec2f,
                @location(1) scale : f32,
                @location(2) rotation : f32,
            }

            @group(0) @binding(2) var<uniform> uTransform : TransformStruct;
            @group(0) @binding(3) var<uniform> uviewport : vec2f;

            @fragment fn fragmentShader( @builtin(position) v_position : vec4f ) -> @location(0) vec4f {
                var position : vec2f = v_position.xy * uviewport / 2;
                position = vec2f(
                    position.x * cos(uTransform.rotation) - position.y * sin(uTransform.rotation),
                    position.x * sin(uTransform.rotation) + position.y * cos(uTransform.rotation)
                );
                position += uTransform.position;
                position *= uTransform.scale;

                let dataIndex : u32 = u32(round(position.x + position.y * sWorldSize.x));
                let tileData : u32 = sWorldData[dataIndex];

                let tileType : u32 = (tileData >> 30) & 3u;
                let hitPoints : u32 = (tileData >> 29) & 1u;

                //     out_color = vec4(0.2, 0.5, 0.4, 1.0); // green stone
                //     out_color = vec4(0.2, 0.2, 0.2, 1.0); // dark stone
                //     out_color = vec4(0.6, 0.5, 0.2, 1.0); // aquarite
                //     out_color = vec4(1.0, 1.0, 1.0, 1.0); // ice

                var out_color : vec4f = vec4f(0.0, 0.0, 0.0, 0.0);

                switch (tileType) {
                    case (TileTypes.GREEN_STONE.id) { out_color = vec4f(0.2, 0.5, 0.4, 1.0); }
                    case (TileTypes.DARK_STONE.id) { out_color = vec4f(0.2, 0.2, 0.2, 1.0); }
                    case (TileTypes.AQUARITE.id) { out_color = vec4f(0.6, 0.5, 0.2, 1.0); }    
                    case (TileTypes.ICE.id) { out_color = vec4f(1.0, 1.0, 1.0, 1.0); }
                    default { out_color = vec4f(0.0, 0.0, 0.0, 1.0); }
                }

                if (hitPoints == 0u) {
                    out_color.x /= 2.0;
                    out_color.y /= 2.0;
                    out_color.z /= 2.0;
                }

                // out_color = vec4f(1.0, 0.0, 0.0, 1.0);

                return out_color;
            }
        `
    });

    const bindGroupLayout = device.createBindGroupLayout({
        label: `generate world bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: { type: "read-only-storage" }
        }, {
            binding: 1,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: { type: "uniform" }
        }, {
            binding: 2,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: { type: "uniform" }
        }, {
            binding: 3,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: { type: "uniform" }
        }]
    });
    
    const pipeline = device.createRenderPipeline({
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

    const worldSizeUniform = device.createBuffer({
        label: `render world world size uniform`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });

    const cameraTransformUniform = device.createBuffer({
        label: `render world camera transform uniform`,
        size: 2 * 4 + // vec2
              1 * 4 + // f32
              1 * 4 + // f32
              0 * 4 , // + padding
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });

    const viewportUniform = device.createBuffer({
        label: `render world viewport uniform`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });

    let bindGroup;
    global.bindWorldStorageBuffer = ({ width = 80, height = 60, storageBuffer}) => {
        device.queue.writeBuffer(worldSizeUniform, 0, new Uint32Array([width, height]));

        bindGroup = device.createBindGroup({
            label: `render world bind group`,
            layout: pipeline.getBindGroupLayout(0),
            entries: [{
                binding: 0,
                resource: { buffer: storageBuffer }
            }, {
                binding: 1,
                resource: { buffer: worldSizeUniform }
            }, {
                binding: 2,
                resource: { buffer: cameraTransformUniform}
            }, {
                binding: 3,
                resource: { buffer: viewportUniform }
            }]
        });
    }

    global.writeViewportBuffer = ({ width = Number(canvas.width), height = Number(canvas.height) }) => device.queue.writeBuffer(viewportUniform, 0, new Float32Array([width, height]));
    global.writeTransformUniform = ({ xPos = 0, yPos = 0, scale = 1, rotation = 0}) => device.queue.writeBuffer(cameraTransformUniform, 0, new Float32Array([xPos, yPos, scale, rotation]));

    global.render = (pass) => {
        pass.setPipeline(pipeline);
        pass.setBindGroup(0, bindGroup);
        pass.draw(3);
    };
}