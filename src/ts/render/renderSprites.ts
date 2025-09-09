let device: GPUDevice;
let bindGroupLayout: GPUBindGroupLayout;
let pipeline: GPURenderPipeline;
let bindGroup: GPUBindGroup;

function setUpRenderSprites (parameters: { device: GPUDevice}) {
    device = parameters.device;

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

            const vertexArray : array<vec2f, 3> = array(
                vec2f(-3.0, -1.0),
                vec2f(0.0, 2.0),
                vec2f(3.0, -3.0),
            );

            @group(0) @binding(4) var<storage, read> sSprites : array<u32>;

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
            @group(0) @binding(2) var spritesheet : texture_2d<f32>;
            @group(0) @binding(3) var sampler : sampler;

            @fragment fn fragmentShader( @builtin(position) v_position : vec4f ) -> @location(0) vec4f {

                return out_color;
            }
        `
    });

    bindGroupLayout = device.createBindGroupLayout({
        label: `render sprites bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.VERTEX,
            buffer: { type: "uniform" }
        } as GPUBindGroupLayoutEntry, {
            binding: 1,
            visibility: GPUShaderStage.VERTEX,
            buffer: { type: "uniform" }
        } as GPUBindGroupLayoutEntry, {
            binding: 2,
            visibility: GPUShaderStage.FRAGMENT,
            externalTexture: {}
        } as GPUBindGroupLayoutEntry, {
            binding: 3,
            visibility: GPUShaderStage.FRAGMENT,
            sampler: { type: "non-filtering" }
        } as GPUBindGroupLayoutEntry, {
            binding: 4,
            visibility: GPUShaderStage.VERTEX,
            buffer: { type: "storage" }
        } as GPUBindGroupLayoutEntry]
    });
    
    pipeline = device.createRenderPipeline({
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
}

function bindSpritesStorageBuffer (parameters: { width, height }) {
    const { width, height, storageBuffer} = parameters;

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

function renderSprites (pass: GPURenderPassEncoder) {
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(3);
};