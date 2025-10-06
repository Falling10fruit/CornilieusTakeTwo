let device: GPUDevice;
let bindGroupLayout: GPUBindGroupLayout;
let pipeline: GPUComputePipeline;

/** Initializes methods for the [generateWorld](generateWorldShader.ts) module.
 * 
 * Implementation at {@link setUpGenerateWorld} */
async function setUpGenerateWorld (parameters: { device: GPUDevice }) {
    device = parameters.device;

    const computeShader = device.createShaderModule({
        label: `generate world shader`,
        code: `
            //  MIT License. © Ian McEwan, Stefan Gustavson, Munrocket, Johan Helsing
            // https://gist.github.com/munrocket/236ed5ba7e409b8bdf1ff6eca5dcdc39
            fn mod289(x: vec2f) -> vec2f {
                return x - floor(x * (1. / 289.)) * 289.;
            }

            fn mod289_3(x: vec3f) -> vec3f {
                return x - floor(x * (1. / 289.)) * 289.;
            }

            fn permute3(x: vec3f) -> vec3f {
                return mod289_3(((x * 34.) + 1.) * x);
            }

            //  MIT License. © Ian McEwan, Stefan Gustavson, Munrocket
            fn simplexNoise2(v: vec2f) -> f32 {
                let C = vec4(
                    0.211324865405187, // (3.0-sqrt(3.0))/6.0
                    0.366025403784439, // 0.5*(sqrt(3.0)-1.0)
                    -0.577350269189626, // -1.0 + 2.0 * C.x
                    0.024390243902439 // 1.0 / 41.0
                );

                // First corner
                var i = floor(v + dot(v, C.yy));
                let x0 = v - i + dot(i, C.xx);

                // Other corners
                var i1 = select(vec2(0., 1.), vec2(1., 0.), x0.x > x0.y);

                // x0 = x0 - 0.0 + 0.0 * C.xx ;
                // x1 = x0 - i1 + 1.0 * C.xx ;
                // x2 = x0 - 1.0 + 2.0 * C.xx ;
                var x12 = x0.xyxy + C.xxzz;
                x12.x = x12.x - i1.x;
                x12.y = x12.y - i1.y;

                // Permutations
                i = mod289(i); // Avoid truncation effects in permutation

                var p = permute3(permute3(i.y + vec3(0., i1.y, 1.)) + i.x + vec3(0., i1.x, 1.));
                var m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), vec3(0.));
                m *= m;
                m *= m;

                // Gradients: 41 points uniformly over a line, mapped onto a diamond.
                // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)
                let x = 2. * fract(p * C.www) - 1.;
                let h = abs(x) - 0.5;
                let ox = floor(x + 0.5);
                let a0 = x - ox;

                // Normalize gradients implicitly by scaling m
                // Approximation of: m *= inversesqrt( a0*a0 + h*h );
                m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

                // Compute final noise value at P
                let g = vec3(a0.x * x0.x + h.x * x0.y, a0.yz * x12.xz + h.yz * x12.yw);
                return 130. * dot(m, g);
            }

            struct TileFormat { id : u32, hitPoints : u32 }
            struct TileTypesStruct { GREEN_STONE : TileFormat, DARK_STONE : TileFormat, AQUARITE : TileFormat, ICE : TileFormat }
            const TileTypes : TileTypesStruct = TileTypesStruct(
                TileFormat(0u, 15u), // GREEN_STONE
                TileFormat(1u, 20u), // DARK_STONE
                TileFormat(2u, 10u), // AQUARITE
                TileFormat(3u, 5u)  // ICE
            );

            @group(0) @binding(0) var<storage, read_write> sWorldData : array<u32>;

            @compute @workgroup_size(16, 16, 1) fn cShader(
                @builtin(global_invocation_id) global_invocation_id : vec3u,
                @builtin(num_workgroups) dispatchSize : vec3u
            ) {
                
                // tileType (<<30) hitPoints (<<25)
                //      01              01010       1 01010101 01010101 01010101
                var tileData : TileFormat;
                let coord : vec2f = vec2f(global_invocation_id.xy);
    
                let biome : f32 = abs(simplexNoise2(coord/100.0));
                     if (biome < 0.3) { tileData = TileTypes.GREEN_STONE; }
                else if (biome < 0.8) { tileData = TileTypes.DARK_STONE; }
                else if (biome < 0.9) { tileData = TileTypes.AQUARITE; }
                else                  { tileData = TileTypes.ICE; }

                let carving : f32 = abs(simplexNoise2(coord/40.0));
                if (carving < 0.4) { tileData.hitPoints = 0u; }

                let tileIndex : u32 = global_invocation_id.x + global_invocation_id.y * dispatchSize.x * 16;
                sWorldData[tileIndex] = ((tileData.id        & 3u ) << 30)  +
                                        ((tileData.hitPoints & 31u) << 25);
                
                // sWorldData[tileIndex] = u32(carving * 100.0 + 100.0); // Just to make sure it works
            }
        `
    });

    bindGroupLayout = device.createBindGroupLayout({
        label: `generate world bind group layout`,
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.COMPUTE,
            buffer: { type: "storage" }
        }]
    });

    pipeline = await device.createComputePipelineAsync({
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
}

async function generateWorldToBuffer (parameters: { width: number, height: number }) {
    const { width, height } = parameters;

    if (window.world.storageBuffer == null) return window.fail({ title: `world storage buffer is null`, message: `error generated at generateWorldShader`})
    const bindGroup = device.createBindGroup({
        label: `generate world bind group`,
        layout: pipeline.getBindGroupLayout(0),
        entries: [{ binding: 0, resource: { buffer: window.world.storageBuffer } }]
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

export { setUpGenerateWorld, generateWorldToBuffer }