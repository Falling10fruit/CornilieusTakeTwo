            const vss = `#version 300 es
            in vec2 a_bufferToIterate;
            uniform vec2 u_worldSize;
            out vec2 v_position;

            void main () {
                v_position = (a_bufferToIterate/2.0 + vec2(0.5, 0.5))*u_worldSize;
                // v_position = a_bufferToIterate*100.0;

                gl_Position = vec4(a_bufferToIterate, 0.0, 1.0);
            }
            `;

            const fss = `#version 300 es
            precision highp float;

            in vec2 v_position;
            out vec4 out_color;

            // Simplex 2D noise
            // https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
            vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

            float snoise(vec2 v){
                const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                        -0.577350269189626, 0.024390243902439);
                vec2 i  = floor(v + dot(v, C.yy) );
                vec2 x0 = v -   i + dot(i, C.xx);
                vec2 i1;
                i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
                vec4 x12 = x0.xyxy + C.xxzz;
                x12.xy -= i1;
                i = mod(i, 289.0);
                vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
                + i.x + vec3(0.0, i1.x, 1.0 ));
                vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
                    dot(x12.zw,x12.zw)), 0.0);
                m = m*m ;
                m = m*m ;
                vec3 x = 2.0 * fract(p * C.www) - 1.0;
                vec3 h = abs(x) - 0.5;
                vec3 ox = floor(x + 0.5);
                vec3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
                vec3 g;
                g.x  = a0.x  * x0.x  + h.x  * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }
            
            void main () {
                float biome = snoise(v_position/50.0)/2.0 + 0.5;

                // if (biome < 0.3) {
                //     out_color = vec4(0.2, 0.5, 0.4, 1.0); // green stone
                // } else if (biome < 0.8) {
                //     out_color = vec4(0.2, 0.2, 0.2, 1.0); // dark stone
                // } else if (biome < 0.9) {
                //     out_color = vec4(0.6, 0.5, 0.2, 1.0); // aquarite
                // } else {
                //     out_color = vec4(1.0, 1.0, 1.0, 1.0); // ice
                // }
                
                if (biome < 0.3) {
                    out_color.xy = vec2(0.0, 6.0); // green stone
                } else if (biome < 0.8) {
                    out_color.xy = vec2(1.0, 8.0); // dark stone
                } else if (biome < 0.9) {
                    out_color.xy = vec2(2.0, 4.0); // aquarite
                } else {
                    out_color.xy = vec2(3.0, 2.0); // ice
                }
                out_color /= 255.0;

                float carving = snoise(v_position/20.0)*snoise(v_position/20.0);
                if (carving < 0.15) {
                    out_color.y = 0.0;
                }

                // out_color *= carving;
                // out_color = vec4(carving, carving, carving, 1.0);

                // if (carving < 0.15) {
                //     out_color *= 0.5;
                // }
                
                out_color.zw = vec2(1.0, 1.0); // make it visible
            }`;

const vs = window.createShader(window.gl, window.gl.VERTEX_SHADER, vss);
const fs = window.createShader(window.gl, window.gl.FRAGMENT_SHADER, fss);
const generateWorldProgram = window.createProgram(window.gl, vs, fs);

window.gl.useProgram(generateWorldProgram);
const worldSizeUniformLocation = window.gl.getUniformLocation(generateWorldProgram, 'u_worldSize');

const generationVAO = window.gl.createVertexArray();
window.gl.bindVertexArray(generationVAO); // binding vao is window.global

const positionAttributeLocation = window.gl.getAttribLocation(generateWorldProgram, 'a_bufferToIterate');
window.gl.bindBuffer(window.gl.ARRAY_BUFFER, window.gl.createBuffer());
window.gl.bufferData(window.gl.ARRAY_BUFFER, new Float32Array([
    -1, -1,
    1, -1, 
    -1, 1,
    1, 1,
]), window.gl.STATIC_DRAW);
window.gl.enableVertexAttribArray(positionAttributeLocation);
window.gl.vertexAttribPointer(positionAttributeLocation, 2, window.gl.FLOAT, false, 0, 0);

const fboGeneratedWorld = window.gl.createFramebuffer();
window.gl.bindFramebuffer(window.gl.FRAMEBUFFER, fboGeneratedWorld);

const textureGeneratedWorld = window.gl.createTexture();
window.gl.bindTexture(window.gl.TEXTURE_2D, textureGeneratedWorld);
window.gl.texParameteri(window.gl.TEXTURE_2D, window.gl.TEXTURE_MIN_FILTER, window.gl.NEAREST);
window.gl.texParameteri(window.gl.TEXTURE_2D, window.gl.TEXTURE_MAG_FILTER, window.gl.NEAREST);
window.gl.texImage2D(window.gl.TEXTURE_2D, 0, window.gl.RGBA, 0, 0, 0, window.gl.RGBA, window.gl.UNSIGNED_BYTE, null);
window.gl.framebufferTexture2D(window.gl.FRAMEBUFFER, window.gl.COLOR_ATTACHMENT0, window.gl.TEXTURE_2D, textureGeneratedWorld, 0);

window.generateWorldTexture = (width = 1600, height = 900, seed = 0) => {
    canvas.width = width;
    canvas.height = height;
    window.gl.viewport(0, 0, width, height);
    window.gl.useProgram(generateWorldProgram);
    window.gl.uniform2f(worldSizeUniformLocation, width, height);
    
    window.gl.bindVertexArray(generationVAO);
        
    window.gl.bindTexture(window.gl.TEXTURE_2D, textureGeneratedWorld);
    window.gl.texImage2D(window.gl.TEXTURE_2D, 0, window.gl.RGBA, width, height, 0, window.gl.RGBA, window.gl.UNSIGNED_BYTE, null);
    window.gl.bindFramebuffer(window.gl.FRAMEBUFFER, fboGeneratedWorld);
    
    window.gl.drawArrays(window.gl.TRIANwindow.glE_STRIP, 0, 4);
    return textureGeneratedWorld;
}

// console.table(world);
// console.log("look mom i generated: " + window.generateWorldUint8Array(world.width, world.height, world.seed));
