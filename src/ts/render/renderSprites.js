/*
                                 y        x     rotation   sprite
                              11111111 11111111 11111111  11111111 
(16 tiles * 16 pixels) = 2**8 = 255      255      255       255
                     591645

*/
const global = window.renderSprites = {
    sprites: Float32Array[20 * 10**6] // max sprites
};
global.setUp = (device) => {
    const vShader = device.createShaderModule({
        label: `render sprites vertex shader`,
        code: `
            struct TransformStruct {
                @location(0) translate : vec2f,
                @location(1) scale : f32,
                @location(2) rotation : f32,
            }

            @group(0) @binding(0) var<uniform> uTransform : TransformStruct;
            @group(0) @binding(1) var<uniform> uViewport : vec2f;
            @group(0) @binding(2) var spritesheet : texture_2d<f32>;

            const vertexArray : array<vec2f, 3> = array(
                vec2f(-3.0, -1.0),
                vec2f(0.0, 2.0),
                vec2f(3.0, -3.0),
            );

            @group(0) @binding(3) var<storage, read> sSprites : array<u32>;

            @vertex fn vertexShader(
                @builtin(vertex_index) vertexIndex : u32,
                @builtin(instance_index)    
            ) -> @builtin(position) vec4f {
                let spriteData = sSprites[instance_index];
                let xPos = (sprite << 24) & 255u;
                let yPos = (sprite << 16) & 255u;
                let rotation = (sprite << 8) & 255u;
                let sprite = (sprite << 0) & 255u;

                return vec4f(vertexArray[vertexIndex], 0.0, 1.0);
            }
        `
    });

    const fShader = device.createShaderModule({
        label: `render sprites fragment shader`,
        code: `
            @group(0) @binding(4) var<sampler>;

            @fragment fn fragmentShader( @builtin(position) v_position : vec4f ) -> @location(0) vec4f {

                return out_color;
            }
        `
    });

    const bindGroupLayout = device.createBindGroupLayout({
        label: `render sprites bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.VERTEX,
            buffer: { type: "read-only-storage" }
        }, {
            binding: 1,
            visibility: GPUShaderStage.VERTEX,
            buffer: { type: "uniform" }
        }, {

        }, {
            binding: 3,
            visibility: GPUShaderStage.VERTEX,
            buffer: { type: "uniform" }
        }, {
            binding: 4,
            visibility: GPUShaderStage.FRAGMENT,
            buffer: { type: "uniform" }
        }]
    });
    
    const pipeline = device.createRenderPipeline({
        label: `render sprites pipeline`,
        layout: device.createPipelineLayout({
            label: `render sprites pipeline layout`,
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

    let bindGroup;
    global.bindSpritesStorageBuffer = ({ width = 80, height = 60, storageBuffer}) => {
        device.queue.writeBuffer(worldSizeUniform, 0, new Float32Array([width * 16, height * 16]));

        bindGroup = device.createBindGroup({
            label: `render sprites bind group`,
            layout: pipeline.getBindGroupLayout(0),
            entries: [{
                binding: 0,
                resource: { buffer: window.camera.transformUniform}
            }, {
                binding: 1,
                resource: { buffer: window.viewportUniform }
            }, {
                binding: 2,
                resource: { buffer: storageBuffer }
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