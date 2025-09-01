const global = window.generateWorld = {};
global.setUp = (device) => {
    const computeShader = device.createShaderModule({
        label: `generate world shader`,
        code: `
            // Simplex 2D noise
            // https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83

            fn permute(x : vec3f) -> vec3f {
                var newX : vec3f = (34.0*x + 1.0) * x;
                return newX - floor(newX / 289.0) * 289.0;
            }
            
            fn snoise(v : vec2f) -> f32 {
                const C : vec4f = vec4(0.211324865405187, 0.366025403784439,-0.577350269189626, 0.024390243902439);

                var i : vec2f = floor(v + dot(v, C.yy));
                                
                let x0 : vec2f = v - i + dot(i, C.xx);
                
                let i1 : vec2f = select(vec2(1.0, 0.0), vec2(0.0, 1.0), (x0.x > x0.y));
                
                var x12 : vec4f = x0.xyxy + C.xxzz;
                x12.x -= i1.x;
                x12.y -= i1.y;
                
                i = i - floor(i / 289.0) * 289.0;
                
                let p : vec3f = permute( permute( i.y + vec3(0.0, i1.y, 1.0 )) + i.x + vec3(0.0, i1.x, 1.0 ));

                var m : vec3f = vec3f(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw));
                // m = max(0.5 - m, 0.0);
                m.x = max(0.5 - m.x, 0.0);
                m.y = max(0.5 - m.y, 0.0);
                m.z = max(0.5 - m.z, 0.0);
                // m = pow(m, 4.0);
                m.x = pow(m.x, 4.0);
                m.y = pow(m.y, 4.0);
                m.z = pow(m.z, 4.0);
                
                let x : vec3f = 2.0 * fract(p * C.www) - 1.0;
                
                let h : vec3f = abs(x) - 0.5;
                
                let ox : vec3f = floor(x + 0.5);
                
                let a0 : vec3f = x - ox;
                
                m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
                
                var g : vec3f;
                g.x = a0.x  * x0.x  + h.x  * x0.y;
                g.y = a0.y * x12.x + h.y * x12.y;
                g.z = a0.z * x12.z + h.z * x12.w;
                
                return 130.0 * dot(m, g);
            }

            struct TileFormat { id : u32, hitPoints : u32 }
            struct TileTypesStruct { GREEN_STONE : TileFormat, DARK_STONE : TileFormat, AQUARITE : TileFormat, ICE : TileFormat }
            const TileTypes : TileTypesStruct = TileTypesStruct(
                TileFormat(0u, 6u), // GREEN_STONE
                TileFormat(1u, 8u), // DARK_STONE
                TileFormat(2u, 4u), // AQUARITE
                TileFormat(3u, 2u)  // ICE
            );

            @group(0) @binding(0) var<storage, read_write> sWorldData : array<u32>;

            @compute @workgroup_size(16, 16, 1) fn cShader(
                @builtin(global_invocation_id) global_invocation_id : vec3u,
                @builtin(num_workgroups) dispatchSize : vec3u
            ) {
                
                // tileType (<<30) hitPoints (<<29)
                //      01                0         10101 01010101 01010101 01010101
                var tileData : TileFormat;
                let coord : vec2f = vec2f(global_invocation_id.xy);
    
                let biome : f32 = abs(snoise(coord));
                     if (biome < 0.3) { tileData = TileTypes.GREEN_STONE; }
                else if (biome < 0.8) { tileData = TileTypes.DARK_STONE; }
                else if (biome < 0.9) { tileData = TileTypes.AQUARITE; }
                else                  { tileData = TileTypes.ICE; }

                let carving : f32 = abs(snoise(coord));
                if (carving < 0.4) { tileData.hitPoints = 0u; }

                let tileIndex : u32 = global_invocation_id.x + global_invocation_id.y * dispatchSize.x;
                sWorldData[tileIndex] = ((tileData.id        & 3u) << 30)  +
                                        ((tileData.hitPoints & 1u) << 29);
                
                // sWorldData[tileIndex] = tileData.id; // Just to make sure it works
            }
        `
    });

    const bindGroupLayout = device.createBindGroupLayout({
        label: `generate world bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.COMPUTE,
            buffer: { type: "storage" }
        }]
    });

    const pipeline = device.createComputePipeline({
        label: `generate world pipeline`,
        layout: device.createPipelineLayout({
            label: `generate world pipeline layout`,
            bindGroupLayouts: [bindGroupLayout],
        }),
        compute: {
            module: computeShader,
            entryPoint: "cShader",
        }
    });

    global.generateWorldStorageBuffer = ({ width = 80, height = 60 }) => {
        return device.createBuffer({
            label: `world data buffer`,
            size: width * height * 256 * 4, // 16 * 16 tiles per chunk, 4 bytes each
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
        });
    }

    global.generateWorldToBuffer = ({ width = 80, height = 60, worldBuffer }) => {
        const bindGroup = device.createBindGroup({
            label: `generate world bind group`,
            layout: pipeline.getBindGroupLayout(0),
            entries: [{ binding: 0, resource: { buffer: worldBuffer } }]
        });

        const encoder = device.createCommandEncoder({ label: `generate world command encoder` });
        const pass = encoder.beginComputePass({ label: `generate world compute pass` });
        pass.setPipeline(pipeline);
        pass.setBindGroup(0, bindGroup);
        pass.dispatchWorkgroups(width, height);
        pass.end();

        // const readBuffer = device.createBuffer({ label: `generateWorld readBuffer`, size: width * height * 256 * 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST});
        // encoder.copyBufferToBuffer(worldBuffer, 0, readBuffer, 0, readBuffer.size);

        device.queue.submit([encoder.finish()]);

        // readBuffer.mapAsync(GPUMapMode.READ).then(() => {
        //     console.log(new Uint32Array(readBuffer.getMappedRange()));
        //     readBuffer.unmap();
        // });
    }
}