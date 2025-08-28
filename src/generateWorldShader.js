const global = window.generateWorld = {};
global.setUp = () => {
    const computeShader = device.createShaderModule({
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

            @group(0) @binding(0) var<storage, write> u_worldData : texture_storage_2d<u32, write>;

            struct TileTypes {
                const GRASS 
            }

            @compute @workgroup_size(16, 16, 1) fn cShader(
                @builtin(global_invocation_id) v_position : vec3u
                @builtin(workgroup_id) workgroupSize : vec3u
            ) -> @builtin(position) vec4f {
                var tileData : u32;
                var biomeData : u32;
                var health
            
                let biome : f32 = 1.0;

                if (biome < 0.3) {
                    outColor.r
                }
            }
        `
    });

    const layout = device.createPipelineLayout({
        label: `generate world pipeline layout`,
        bindGroupLayouts: [{
            binding: 0,

        }],
    });

    const pipeline = device.createComputePipeline({
        layout,
        compute: {
            module: computeShader,
            entryPoint: "cShader",
        }
    });
}

window.generateWorldTexture = (width = 1600, height = 900, seed = 0) => {
}