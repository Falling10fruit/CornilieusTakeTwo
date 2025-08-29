const global = window.generateWorld = {};

global.setUp = () => {
    const computeShader = window.device.createShaderModule({
        label: `generate world shader`,
        code: `
            fn permute(x : vec3f) -> vec3f { return mod(((x*34.0)+1.0)*x, 289.0); }
            
            fn snoise(v : vec2f) -> f32 {
                const C : vec4f = vec4(0.211324865405187, 0.366025403784439,-0.577350269189626, 0.024390243902439);
                                
                let x0 : vec2f = v - i + dot(i, C.xx);
                
                let i1 : vec2f = select(vec2(1.0, 0.0), vec2(0.0, 1.0), (x0.x > x0.y));
                
                var x12 : vec4f = x0.xyxy + C.xxzz;
                x12.x -= i1;
                x12.y -= i1;
                
                i = mod(i, 289.0);
                
                let p : vec3f = permute( permute( i.y + vec3(0.0, i1.y, 1.0 )) + i.x + vec3(0.0, i1.x, 1.0 ));
                
                var m : vec3f = pow(max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0), 4.0);
                
                let x : vec3f = 2.0 * fract(p * C.www) - 1.0;
                
                let h : vec3f = abs(x) - 0.5;
                
                let ox : vec3f = floor(x + 0.5);
                
                let a0 : vec3f = x - ox;
                
                m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
                
                let gx : 32f = a0.x  * x0.x  + h.x  * x0.y;
                let gyz : 32f = a0.yz * x12.xz + h.yz * x12.yw;
                let g : vec3f = vec3(gx, gyz, gyz);
                
                return 130.0 * dot(m, g);
            }

            struct TileFormat { id : u32, hitPoints : u32 }

            struct TileTypes {
                const GREEN_STONE : TileFormat = TileFormat(0u, 6u);
                const DARK_STONE  : TileFormat = TileFormat(1u, 8u);
                const AQUARITE    : TileFormat = TileFormat(2u, 4u);
                const ICE         : TileFormat = TileFormat(3u, 2u);
            }

            @group(0) @binding(0) var<storage, write> sworldData : texture_storage_2d<u32, write>;

            @compute @workgroup_size(16, 16, 1) fn cShader(
                @builtin(global_invocation_id) global_invocation_id : vec3u
                @builtin(num_workgroups) dispatchSize : vec3u
            ) -> @builtin(position) vec4f {
                
                // tileType (<<30) carved (<<29)
                //      01              0        10101 01010101 01010101 01010101
                var tileData : TileFormat;
    
                let biome : f32 = 1.0;
                     if (biome < 0.3) { tileData = TileTypes.GREEN_STONE; }
                else if (biome < 0.8) { tileData = TileTypes.DARK_STONE; }
                else if (biome < 0.9) { tileData = TileTypes.AQUARITE; }
                else                  { tileData = TileTypes.ICE; }

                let carving : f32 = 1.0;
                if (carving < 0.15) { tileData.hitPoints = 0u; }

                let tileIndex : u32 = global_invocation_id.x + global_invocation_id.y * dispatchSize.x;
                sWorldData[tileIndex] = (tileData.id      & 3u) << 30  +
                                        (carved.hitPoints & 1u) << 29;
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

    const pipeline = window.device.createComputePipeline({
        label: `generate world pipeline`,
        layout: window.device.createPipelineLayout({
            label: `generate world pipeline layout`,
            bindGroupLayouts,
        }),
        compute: {
            module: computeShader,
            entryPoint: "cShader",
        }
    });

    window.generateWorldTexture = (width = 80, height = 60, seed = 0) => { 
        const worldDataBuffer = window.device.createBuffer({
            label: `world data buffer`,
            size: width * height * 256 * 4, // 16 * 16 tiles per chunk, 4 bytes each
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
        });

        const bindGroup = window.device.createBindGroup({
            label: `generate world bind group`,
            layout: pipeline.getBindGroupLayout(0),
            entries: [{ binding: 0, resource: { buffer: worldDataBuffer } }]
        });

        const commandEncoder = window.device.createCommandEncoder({ label: `generate world command encoder` });
        const passEncoder = commandEncoder.beginComputePass({ label: `generate world compute pass` });
        passEncoder.setPipeline(pipeline);
        passEncoder.setBindGroup(0, bindGroup);
        passEncoder.dispatchWorkgroups(width, height);
        passEncoder.end();
        window.device.queue.submit([commandEncoder.finish()]);

        return worldDataBuffer;
    }
}