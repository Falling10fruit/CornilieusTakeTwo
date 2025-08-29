const global = window.renderWorld = {};
global.setUp = () => {
    const vShader = window.device.createShaderModule({
        label: `world vertex shader`,
        code: `
            const vertexArray : array<vec2f, 4> = array(
                vec2f(2.0, -1.0),
                vec2f(-1.0, -1.0),
                vec2f(2.0, -1.0),
            )

            @vertex fn vertexShader( @builtin(vertex_index) vertexIndex : u32 ) -> @builtin(position) vec4f {

                return vertexArray[vertexIndex] * vec2f(1.0, -1.0);
            }
        `
    });

    const fShader = window.device.createShaderModule({
        label: `world fragment shader`,
        code: `
            struct TileFormat { id : u32, hitPoints : u32 }

            @group(0) @binding(0) var<storage, read> uworldData : u32;

            struct Transform {
                @location(0) viewport : vec2f;
                @location(1) cameraPosition : vec2f;
                @location(2) cameraZoom : f32;
            }

            @group(0) @binding(2) var<uniform> u_transform : Transform;

            @fragment fn fragmentShader( @builtin v_position : vec2f ) -> @location(0) vec4f {
                var position : vec2f = v_position * u_transform.viewport;
                position *= u_transform.cameraZoom;
                position += u_transform.cameraPosition;

                let tileData : u32 = textureLoad(u_worldData, vec2i(position), 0);
            }
        `
    });

    const bindGroupLayouts = window.device.createBindGroupLayout({
        label: `generate world bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.COMPUTE,
            buffer: { type: "storage" }
        }]
    });
    
    window.renderWorld.pipeline = window.device.createRenderPipeline({
        label: `render world pipeline`,
        layout: window.device.createPipelineLayout({
            label: `render world pipeline layout`,
            bindGroupLayouts,
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

    window.renderWorld = function() {};
}