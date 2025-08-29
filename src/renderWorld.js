const global = window.renderWorld = {};
global.setUp = () => {
    const vShader = window.device.createShaderModule({
        label: `render world vertex shader`,
        code: `
            const vertexArray : array<vec2f, 3> = array(
                vec2f(2.0, -1.0),
                vec2f(-1.0, -1.0),
                vec2f(2.0, -1.0),
            );

            @vertex fn vertexShader( @builtin(vertex_index) vertexIndex : u32 ) -> @builtin(position) vec4f {
                return vec4f(vertexArray[vertexIndex] * vec2f(1.0, -1.0), 0.0, 1.0);
            }
        `
    });

    const fShader = window.device.createShaderModule({
        label: `render world fragment shader`,
        code: `
            struct TileTypesStruct { GREEN_STONE : TileFormat, DARK_STONE : TileFormat, AQUARITE : TileFormat, ICE : TileFormat }
            const TileTypes : TileTypesStruct = TileTypesStruct(
                TileFormat(0u, 6u), // GREEN_STONE
                TileFormat(1u, 8u), // DARK_STONE
                TileFormat(2u, 4u), // AQUARITE
                TileFormat(3u, 2u)  // ICE
            );

            @group(0) @binding(0) var<storage, read> sWorldData : u32;
            @group(0) @binding(1) var<uniform, read> sWorldSize : vec2f;

            struct Transform {
                @location(0) viewport : vec2f,
                @location(1) cameraPosition : vec2f,
                @location(2) cameraZoom : f32,
            }

            @group(0) @binding(2) var<uniform> u_transform : Transform;

            @fragment fn fragmentShader( @builtin(position) v_position : vec2f ) -> @location(0) vec4f {
                var position : vec2f = v_position * u_transform.viewport / 2;
                position += u_transform.cameraPosition;
                position *= u_transform.cameraZoom;

                let dataIndex : u32 = round(position.x + position.y * sWorldSize.x);
                let tileData : u32 = sWorldData[dataIndex];

                let tileType : u32 = (tileData >> 30) & 3u;
                let hitPoints : u32 = (tileData >> 29) & 1u;

                switch (tileType) {
                    case
            }
        `
    });

    const bindGroupLayout = window.device.createBindGroupLayout({
        label: `generate world bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: { type: "storage" }
        }, {
            binding: 1,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: { type: "uniform" }
        }]
    });
    
    const pipeline = window.device.createRenderPipeline({
        label: `render world pipeline`,
        layout: window.device.createPipelineLayout({
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

    const worldSizeUniform = window.device.createBuffer({
        label: `render world world size uniform`,
        size: 2 * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_SRC
    });

    let bindGroup;
    global.setRenderBuffer = ({ width = 80, height = 60, storageBuffer}) => {
        window.device.queue.writeBuffer(worldSizeUniform, 0, new Uint32Buffer([width, height]));

        bindGroup = window.device.createBindGroup({
            label: `render world bind group`,
            layout: pipeline.getBindGroupLayout(0),
            entries: [{
                binding: 0,
                resource: { buffer: storageBuffer }
            }, {
                binding: 1,
                resource: { buffer: worldSizeUniform }
            }]
        });
    }

    global.renderWorld = function () {
        const commanderEncoder = window.device.createCommandEncoder({ label: `render world command encoder`});
        const pass = commanderEncoder.beginRenderPass(window.renderPassDescriptor);
    };
}